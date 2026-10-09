import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import test from 'node:test';
import ts from 'typescript';

const require = createRequire(import.meta.url);
function load(path, dependencies = {}) {
  const source = readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
  const compiled = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, jsx: ts.JsxEmit.ReactJSX },
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', compiled)(
    (name) => dependencies[name] || require(name),
    module,
    module.exports,
  );
  return module.exports;
}
const ui = load('src/lib/ai/ui.ts', { '@/lib/campus/catalog': load('src/lib/campus/catalog.ts') });
const fixtures = JSON.parse(readFileSync(new URL('./fixtures/ai-ui.json', import.meta.url), 'utf8'));

for (const fixture of fixtures.cases) {
  test(`UI protocol: ${fixture.name}`, () => {
    const result = ui.validateUI(fixture.value, fixtures.sources);
    assert.equal(result.ui?.cards.length || 0, fixture.cards);
    assert.deepEqual(result.errors, fixture.errors);
    if (result.ui) assert.equal(ui.uiEnvelopeSchema.safeParse(result.ui).success, true);
  });
}

test('source links accept only HTTP(S) URLs without credentials', () => {
  for (const value of [
    'javascript:alert(1)',
    'data:text/html,x',
    '/relative',
    'https://user:secret@example.com',
    null,
    '',
  ]) {
    assert.equal(ui.safeSourceURL(value), undefined);
  }
  assert.equal(ui.safeSourceURL('https://news.xidian.edu.cn/doc'), 'https://news.xidian.edu.cn/doc');
});

test('service destinations come from the catalog and never enter model parameters', () => {
  assert.deepEqual(ui.harnessUIContext(undefined), {});
  const context = ui.harnessUIContext(1);
  assert.equal(context.uiVersion, 1);
  assert.equal(
    context.uiServices.some((service) => 'href' in service || 'url' in service),
    false,
  );
  assert.equal(
    ui.getAIUIServices().find((service) => service.id === 'campus-network-usage').href,
    '/campus/network-usage',
  );
});

test('AI page restores recent cards, preserves message order and drops unknown versions', async () => {
  const source = fixtures.sources[0];
  const card = { version: 1, cards: [{ type: 'source_list', citations: [1] }] };
  const createdAt = new Date('2026-10-09T00:00:00Z');
  const messages = [
    { id: 'newest', role: 'ASSISTANT', content: 'answer', sources: [source], ui: card, createdAt },
    {
      id: 'unknown',
      role: 'ASSISTANT',
      content: 'old protocol',
      sources: [],
      ui: { version: 2, cards: [] },
      createdAt,
    },
    { id: 'oldest', role: 'USER', content: 'question', sources: [], ui: null, createdAt },
  ];
  const page = load('src/app/(protected)/ai/page.tsx', {
    '@/lib/getServerUser': { getServerUser: async () => [{ id: 'user' }] },
    '@/lib/getInterfaceLanguage': { getInterfaceLanguage: async () => 'zh' },
    '@/lib/ai/ui': ui,
    './AIChat': { AIChat: () => null },
    '@/lib/prisma/prisma': {
      default: {
        aiConversation: {
          findMany: async (query) => {
            assert.deepEqual(query.where, { userId: 'user' });
            assert.deepEqual(query.include.messages, { orderBy: { createdAt: 'desc' }, take: 40 });
            return [{ id: 'conversation', title: 'example', updatedAt: createdAt, messages }];
          },
        },
        aiTrace: { findMany: async () => [] },
      },
    },
  });
  const result = await page.default();
  const restored = result.props.initialConversations[0].messages;
  assert.deepEqual(
    restored.map((message) => message.id),
    ['oldest', 'unknown', 'newest'],
  );
  assert.deepEqual(restored.at(-1).ui, card);
  assert.equal(restored[1].ui, null);
  assert.equal(restored[0].ui, null);
  assert.equal(
    result.props.services.find((service) => service.id === 'ehall').href,
    'https://ehall.xidian.edu.cn/new/index.html',
  );
});
