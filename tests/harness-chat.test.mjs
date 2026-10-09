import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import test from 'node:test';
import ts from 'typescript';

const require = createRequire(import.meta.url);

function load(path, dependencies = {}, globals = {}) {
  const source = readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
  const compiled = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', ...Object.keys(globals), compiled)(
    (name) => (name in dependencies ? dependencies[name] : require(name)),
    module,
    module.exports,
    ...Object.values(globals),
  );
  return module.exports;
}

const historyModule = load('src/lib/ai/harnessHistory.ts');
const errorsModule = load('src/lib/ai/errors.ts');
const uiModule = load('src/lib/ai/ui.ts', { '@/lib/campus/catalog': load('src/lib/campus/catalog.ts') });
const source = { citation: 1, title: 'Scholarship', documentId: 'doc', source: 'https://example.com/doc' };

function fixture(
  events,
  { holdOpen = false, status = 200, fragment = false, afterTransaction, mockTimeout = false,
    uiVersion, authorized = true, ownsConversation = true } = {},
) {
  const messages = [],
    traces = [];
  const requestAbort = new AbortController();
  let fetchSignal,
    fetchBody,
    upstreamCancelled = false;
  let notifyFailure;
  let expire;
  const failureRecorded = new Promise((resolve) => {
    notifyFailure = resolve;
  });
  const prisma = {
    aiConversation: { findFirst: async () => ownsConversation ? ({ id: 'conversation', title: 'existing' }) : null, update: async () => ({}) },
    aiMessage: {
      create: async ({ data }) => {
        const row = { ...data, id: data.role === 'USER' ? 'user-message' : 'assistant-message', createdAt: new Date() };
        messages.push(row);
        return row;
      },
      findMany: async () => [
        { role: 'ASSISTANT', content: 'Previous answer [1]', sources: [source] },
        { role: 'USER', content: 'Previous question', sources: [] },
      ],
      deleteMany: async ({ where }) => {
        const index = messages.findIndex((message) => message.id === where.id);
        if (index >= 0) messages.splice(index, 1);
        return { count: index >= 0 ? 1 : 0 };
      },
    },
    aiTrace: {
      create: async ({ data }) => {
        traces.push(data);
        if (data.metadata.outcome !== 'complete') notifyFailure();
        return data;
      },
    },
    $transaction: async (fn) => {
      const result = await fn(prisma);
      afterTransaction?.(requestAbort);
      return result;
    },
  };
  const fetch = async (_url, options) => {
    fetchSignal = options.signal;
    fetchBody = JSON.parse(options.body);
    if (status !== 200) return new Response(JSON.stringify({ detail: { code: 'ai_busy' } }), { status });
    const body = new ReadableStream({
      start(controller) {
        const bytes = new TextEncoder().encode(events.map((event) => `data: ${JSON.stringify(event)}\n\n`).join(''));
        if (fragment) {
          for (let offset = 0; offset < bytes.length; offset += 7) controller.enqueue(bytes.slice(offset, offset + 7));
        } else if (bytes.length) controller.enqueue(bytes);
        if (!holdOpen) controller.close();
      },
      cancel() {
        upstreamCancelled = true;
      },
    });
    return new Response(body);
  };
  const dependencies = {
    '@/lib/apiResponse': {
      apiError: (message, code, data) => new Response(JSON.stringify({ message, data }), { status: code }),
    },
    '@/lib/getServerUser': { getServerUser: async () => [authorized ? { id: 'user' } : null] },
    '@/lib/ai/harnessPrincipal': { createAgentPrincipalToken: () => 'signed-test-principal' },
    '@/lib/ai/harnessHistory': historyModule,
    '@/lib/ai/errors': errorsModule,
    '@/lib/ai/ui': uiModule,
    '@/lib/prisma/prisma': { default: prisma },
    'server-only': {},
  };
  const request = new Request('http://localhost/api/ai/chat/stream', {
    method: 'POST',
    body: JSON.stringify({ content: 'question', conversationId: 'conversation', uiVersion }),
    signal: requestAbort.signal,
  });
  const route = load('src/app/api/ai/chat/stream/route.ts', dependencies, {
    fetch,
    ...(mockTimeout
      ? {
          setTimeout: (callback) => {
            expire = callback;
            return 0;
          },
          clearTimeout: () => {},
        }
      : {}),
  });
  return {
    route,
    request,
    requestAbort,
    prisma,
    dependencies,
    messages,
    traces,
    failureRecorded,
    expire: () => expire(),
    get fetchSignal() {
      return fetchSignal;
    },
    get fetchBody() {
      return fetchBody;
    },
    get upstreamCancelled() {
      return upstreamCancelled;
    },
  };
}

function frames(text) {
  return text
    .trim()
    .split('\n\n')
    .map((frame) => JSON.parse(frame.slice(6)));
}

test('history retains source mappings, bounds long replies and excludes unfinished questions', () => {
  const result = historyModule.buildHarnessHistory([
    { role: 'USER', content: 'failed question', sources: [] },
    { role: 'ASSISTANT', content: 'x'.repeat(13_000), sources: [source, null, { title: 'invalid' }] },
    { role: 'USER', content: 'previous question', sources: [] },
  ]);
  assert.equal(result.length, 2);
  assert.equal(result[1].content.length, 12_000);
  assert.deepEqual(result[1].sources, [source]);
  assert.equal(result[0].content, 'previous question');
  assert.deepEqual(historyModule.buildHarnessHistory([{ role: 'USER', content: 'unanswered', sources: [] }]), []);
});

test('successful fragmented SSE persists answer, source map, trace and token usage', async () => {
  const f = fixture(
    [
      { type: 'tool_call', tool: 'read_files', toolCallId: 'read', arguments: { file_ids: ['doc'] } },
      {
        type: 'complete',
        answer: '校园资料 [1]',
        sources: [source],
        usage: { inputTokens: 120, outputTokens: 20 },
        durationMs: 100,
      },
    ],
    { fragment: true },
  );
  const response = await f.route.POST(f.request);
  const events = frames(await response.text());
  assert.equal(events.at(-1).type, 'done');
  assert.equal(f.messages.length, 2);
  assert.equal(f.traces.length, 1);
  assert.equal(f.traces[0].promptTokens, 120);
  assert.equal(f.traces[0].metadata.assistantMessageId, 'assistant-message');
  assert.equal(f.fetchBody.history[1].sources[0].documentId, 'doc');
  assert.equal(f.fetchBody.trace_id, f.traces[0].requestId);
});

test('SSE error removes unfinished user message and records failure with tools and usage', async () => {
  const f = fixture([
    { type: 'tool_result', tool: 'read_files', result: 'x'.repeat(6_000) },
    { type: 'error', code: 'ai_budget_exceeded', usage: { inputTokens: 150, outputTokens: 30 } },
  ]);
  const response = await f.route.POST(f.request);
  assert.equal(frames(await response.text()).at(-1).type, 'error');
  assert.equal(f.messages.length, 0);
  assert.equal(f.traces[0].metadata.outcome, 'ai_budget_exceeded');
  assert.equal(f.traces[0].promptTokens, 150);
  assert.ok(f.traces[0].metadata.agentEvents[0].result.length < 3_100);
});

test('EOF without completion cleans up rather than leaving a question in history', async () => {
  const f = fixture([{ type: 'status', stage: 'thinking' }]);
  const response = await f.route.POST(f.request);
  assert.equal(frames(await response.text()).at(-1).type, 'error');
  assert.equal(f.messages.length, 0);
  assert.equal(f.traces[0].metadata.outcome, 'ai_upstream_error');
});

test('stream deadline cancels stalled upstream and reports timeout rather than a generic failure', async () => {
  const f = fixture([], { holdOpen: true, mockTimeout: true });
  const response = await f.route.POST(f.request);
  const text = response.text();
  f.expire();
  assert.equal(frames(await text).at(-1).code, 'ai_timeout');
  assert.equal(f.fetchSignal.aborted, true);
  assert.equal(f.upstreamCancelled, true);
  assert.equal(f.messages.length, 0);
  assert.equal(f.traces[0].metadata.outcome, 'ai_timeout');
});

test('request disconnect aborts upstream and records cancellation', async () => {
  const f = fixture([{ type: 'status', stage: 'thinking' }], { holdOpen: true });
  const response = await f.route.POST(f.request);
  const reader = response.body.getReader();
  await reader.read();
  f.requestAbort.abort();
  await reader.cancel();
  await f.failureRecorded;
  assert.equal(f.fetchSignal.aborted, true);
  assert.equal(f.upstreamCancelled, true);
  assert.equal(f.messages.length, 0);
  assert.equal(f.traces[0].metadata.outcome, 'cancelled');
});

test('cancelling the response reader also cancels upstream without an HTTP request signal', async () => {
  const f = fixture([], { holdOpen: true });
  const response = await f.route.POST(f.request);
  const reader = response.body.getReader();
  await reader.read();
  await reader.cancel();
  await f.failureRecorded;
  assert.equal(f.fetchSignal.aborted, true);
  assert.equal(f.upstreamCancelled, true);
  assert.equal(f.messages.length, 0);
});

test('disconnect during successful persistence preserves the committed turn', async () => {
  const f = fixture([{ type: 'complete', answer: 'answer', sources: [] }], {
    afterTransaction: (abort) => abort.abort(),
  });
  const response = await f.route.POST(f.request);
  await response.text();
  assert.deepEqual(
    f.messages.map((message) => message.role),
    ['USER', 'ASSISTANT'],
  );
  assert.equal(f.traces.length, 1);
  assert.equal(f.traces[0].metadata.outcome, 'complete');
});

test('upstream rejection before streaming records failure and removes the user message', async () => {
  const f = fixture([], { status: 429 });
  const response = await f.route.POST(f.request);
  assert.equal(response.status, 429);
  assert.equal(f.messages.length, 0);
  assert.equal(f.traces[0].metadata.outcome, 'ai_busy');
});

test('non-streaming harness persists usage and trace-to-message association', async () => {
  const f = fixture([]);
  let payload;
  const helper = load('src/lib/ai/harness.ts', f.dependencies, {
    fetch: async (_url, options) => {
      payload = JSON.parse(options.body);
      return new Response(
        JSON.stringify({ answer: 'answer [1]', sources: [source], usage: { inputTokens: 99, outputTokens: 9 } }),
      );
    },
  });
  const result = await helper.answerWithAgentHarness('user', 'conversation', 'new-question', 'question');
  assert.equal(result.message.id, 'assistant-message');
  assert.equal(f.traces[0].promptTokens, 99);
  assert.equal(f.traces[0].metadata.assistantMessageId, 'assistant-message');
  assert.equal(payload.history[1].sources[0].documentId, 'doc');
});

test('non-streaming errors preserve usage and cancellation reaches fetch', async () => {
  const f = fixture([]);
  const abort = new AbortController();
  let started;
  const fetchStarted = new Promise((resolve) => {
    started = resolve;
  });
  const helper = load('src/lib/ai/harness.ts', f.dependencies, {
    fetch: async (_url, options) => {
      started(options.signal);
      return new Promise((_resolve, reject) =>
        options.signal.addEventListener('abort', () => reject(new Error('cancelled')), { once: true }),
      );
    },
  });
  const pending = helper.answerWithAgentHarness('user', 'conversation', 'new-question', 'question', 'zh', abort.signal);
  const signal = await fetchStarted;
  abort.abort();
  await assert.rejects(pending, /harness_unavailable/);
  assert.equal(signal.aborted, true);
  assert.equal(f.traces[0].metadata.outcome, 'cancelled');
});

test('non-streaming budget rejection records the tokens consumed before failure', async () => {
  const f = fixture([]);
  const helper = load('src/lib/ai/harness.ts', f.dependencies, {
    fetch: async () =>
      new Response(
        JSON.stringify({
          detail: {
            code: 'ai_budget_exceeded',
            usage: { inputTokens: 150, outputTokens: 30 },
          },
        }),
        { status: 429 },
      ),
  });
  await assert.rejects(
    helper.answerWithAgentHarness('user', 'conversation', 'new-question', 'question'),
    /ai_budget_exceeded/,
  );
  assert.equal(f.traces[0].promptTokens, 150);
  assert.equal(f.traces[0].completionTokens, 30);
  assert.equal(f.traces[0].metadata.outcome, 'ai_budget_exceeded');
});

const presentation = { version: 1, cards: [{ type: 'source_list', citations: [1] },
  { type: 'service_links', serviceIds: ['ehall'] }] };

test('opted-in fragmented stream saves validated cards with the answer and returns them only at done', async () => {
  const f = fixture([
    { type: 'tool_result', tool: 'present_ui', toolCallId: 'ui', result: { accepted: true } },
    { type: 'answer_delta', text: 'answer' },
    { type: 'complete', answer: 'answer', sources: [source], ui: presentation },
  ], { uiVersion: 1, fragment: true });
  const events = frames(await (await f.route.POST(f.request)).text());
  assert.deepEqual(events.at(-1).message.ui, presentation);
  assert.deepEqual(f.messages.at(-1).ui, presentation);
  assert.equal(f.traces[0].metadata.uiCards, 2);
  assert.equal(f.fetchBody.uiVersion, 1);
  assert.equal(f.fetchBody.uiServices.find((item) => item.id === 'ehall').name, '一站式服务大厅');
  assert.equal(events.slice(0, -1).some((event) => 'ui' in event), false);
});

test('invalid cards fall back to text and record rejection without losing valid cards', async () => {
  const ui = { version: 1, cards: [{ type: 'source_list', citations: [99] }, presentation.cards[1]] };
  const f = fixture([{ type: 'complete', answer: 'answer', sources: [source], ui }], { uiVersion: 1 });
  const events = frames(await (await f.route.POST(f.request)).text());
  assert.deepEqual(events.at(-1).message.ui.cards, [presentation.cards[1]]);
  assert.deepEqual(f.traces[0].metadata.uiErrors, ['card_0:invalid_source']);
  const unknown = fixture([{ type: 'complete', answer: 'answer', sources: [], ui: { version: 2, cards: [] } }], { uiVersion: 1 });
  const fallback = frames(await (await unknown.route.POST(unknown.request)).text()).at(-1).message;
  assert.equal(fallback.content, 'answer');
  assert.equal(fallback.ui, null);
  assert.equal(unknown.messages.at(-1).ui, undefined);
});

test('legacy clients never request or persist cards', async () => {
  const f = fixture([{ type: 'complete', answer: 'answer', sources: [source], ui: presentation }]);
  const done = frames(await (await f.route.POST(f.request)).text()).at(-1);
  assert.equal(f.fetchBody.uiVersion, undefined);
  assert.equal(f.fetchBody.uiServices, undefined);
  assert.equal(done.message.ui, null);
  assert.equal(f.messages.at(-1).ui, undefined);
});

test('a failed card turn never persists a presentation', async () => {
  const f = fixture([
    { type: 'tool_result', tool: 'present_ui', toolCallId: 'ui', result: { accepted: true } },
    { type: 'error', code: 'ai_timeout' },
  ], { uiVersion: 1 });
  const events = frames(await (await f.route.POST(f.request)).text());
  assert.equal(events.at(-1).type, 'error');
  assert.equal(f.messages.length, 0);
  assert.equal(f.traces[0].metadata.outcome, 'ai_timeout');
});

test('unauthenticated users and other users conversations cannot reach the harness', async () => {
  for (const [options, status] of [[{ authorized: false }, 401], [{ ownsConversation: false }, 404]]) {
    const f = fixture([], { ...options, uiVersion: 1 });
    assert.equal((await f.route.POST(f.request)).status, status);
    assert.equal(f.fetchBody, undefined);
    assert.equal(f.messages.length, 0);
  }
});

test('non-streaming harness uses the same card validation and persistence', async () => {
  const f = fixture([]);
  let requestBody;
  const helper = load('src/lib/ai/harness.ts', f.dependencies, {
    fetch: async (_url, options) => {
      requestBody = JSON.parse(options.body);
      return new Response(JSON.stringify({ answer: 'answer', sources: [source], ui: presentation }));
    },
  });
  const result = await helper.answerWithAgentHarness('user', 'conversation', 'new-question', 'question', 'zh', undefined, 1);
  assert.deepEqual(result.message.ui, presentation);
  assert.equal(requestBody.uiVersion, 1);
  assert.equal(f.traces[0].metadata.uiCards, 2);
});
