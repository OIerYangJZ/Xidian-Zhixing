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

/** In-memory stand-in for the three tables one conversation delete touches. */
function fixture({ authorized = true, ownsConversation = true } = {}) {
  const state = {
    conversations: [
      { id: 'conversation', userId: 'user', title: 'owned' },
      { id: 'other-conversation', userId: 'other-user', title: 'someone else' },
    ],
    messages: [
      { id: 'm1', conversationId: 'conversation', role: 'USER' },
      { id: 'm2', conversationId: 'conversation', role: 'ASSISTANT' },
      { id: 'm3', conversationId: 'other-conversation', role: 'USER' },
    ],
    traces: [
      { id: 't1', userId: 'user', metadata: { conversationId: 'conversation', outcome: 'complete' } },
      { id: 't2', userId: 'user', metadata: { conversationId: 'other-conversation', outcome: 'complete' } },
      { id: 't3', userId: 'other-user', metadata: { conversationId: 'conversation', outcome: 'complete' } },
    ],
    order: [],
  };
  const prisma = {
    aiConversation: {
      findFirst: async ({ where }) =>
        ownsConversation && where.id === 'conversation' && where.userId === 'user'
          ? { id: 'conversation', title: 'owned' }
          : null,
      delete: async ({ where }) => {
        state.order.push('conversation');
        state.conversations = state.conversations.filter((row) => row.id !== where.id);
        return { id: where.id };
      },
      update: async ({ where, data }) => ({ id: where.id, title: data.title }),
    },
    aiMessage: {
      deleteMany: async ({ where }) => {
        state.order.push('messages');
        const before = state.messages.length;
        state.messages = state.messages.filter((row) => row.conversationId !== where.conversationId);
        return { count: before - state.messages.length };
      },
    },
    aiTrace: {
      deleteMany: async ({ where }) => {
        state.order.push('traces');
        const before = state.traces.length;
        // Prisma's JSON filter shape: `{ path: ['conversationId'], equals: <id> }`.
        const key = Array.isArray(where.metadata.path) ? where.metadata.path[0] : where.metadata.path;
        state.traces = state.traces.filter(
          (row) => !(row.userId === where.userId && row.metadata[key] === where.metadata.equals),
        );
        return { count: before - state.traces.length };
      },
    },
    $transaction: async (fn) => fn(prisma),
  };
  const dependencies = {
    '@/lib/apiResponse': {
      apiError: (message, status, data) => new Response(JSON.stringify({ message, data }), { status }),
      apiSuccess: (payload, status = 200) => new Response(JSON.stringify({ data: payload }), { status }),
    },
    '@/lib/getServerUser': { getServerUser: async () => [authorized ? { id: 'user' } : null] },
    '@/lib/prisma/prisma': { default: prisma },
    'server-only': {},
  };
  return {
    state,
    route: load('src/app/api/ai/conversations/[conversationId]/route.ts', dependencies),
  };
}

const context = (conversationId = 'conversation') => ({ params: Promise.resolve({ conversationId }) });

test('deleting a conversation removes its traces, then its messages, then the row itself', async () => {
  const f = fixture();
  const response = await f.route.DELETE(new Request('http://localhost', { method: 'DELETE' }), context());
  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.deepEqual(payload.data, { id: 'conversation', deletedMessages: 2, deletedTraces: 1 });
  // `onDelete: Restrict` means the order is not cosmetic: children must go before the parent.
  assert.deepEqual(f.state.order, ['traces', 'messages', 'conversation']);
  assert.deepEqual(
    f.state.conversations.map((row) => row.id),
    ['other-conversation'],
  );
  assert.deepEqual(
    f.state.messages.map((row) => row.id),
    ['m3'],
  );
  assert.deepEqual(
    f.state.traces.map((row) => row.id),
    ['t2', 't3'],
  );
});

test('another account cannot delete a conversation it does not own', async () => {
  const f = fixture({ ownsConversation: false });
  const response = await f.route.DELETE(new Request('http://localhost', { method: 'DELETE' }), context());
  assert.equal(response.status, 404);
  assert.deepEqual(f.state.order, []);
  assert.equal(f.state.conversations.length, 2);
});

test('an unauthenticated delete changes nothing', async () => {
  const f = fixture({ authorized: false });
  const response = await f.route.DELETE(new Request('http://localhost', { method: 'DELETE' }), context());
  assert.equal(response.status, 401);
  assert.deepEqual(f.state.order, []);
});

test('renaming keeps ownership scoped and rejects an empty title', async () => {
  const f = fixture();
  const renamed = await f.route.PATCH(
    new Request('http://localhost', { method: 'PATCH', body: JSON.stringify({ title: '  奖学金  ' }) }),
    context(),
  );
  assert.equal(renamed.status, 200);
  assert.deepEqual((await renamed.json()).data, { id: 'conversation', title: '奖学金' });

  const blank = await f.route.PATCH(
    new Request('http://localhost', { method: 'PATCH', body: JSON.stringify({ title: '   ' }) }),
    context(),
  );
  assert.equal(blank.status, 400);

  const foreign = fixture({ ownsConversation: false });
  const denied = await foreign.route.PATCH(
    new Request('http://localhost', { method: 'PATCH', body: JSON.stringify({ title: 'x' }) }),
    context(),
  );
  assert.equal(denied.status, 404);
});
