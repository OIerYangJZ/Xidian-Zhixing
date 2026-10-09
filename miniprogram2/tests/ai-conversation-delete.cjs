// The mini program keeps its own copy of the conversation list in storage, but the answers live in
// the server conversation that `backendId` points at. Deleting must reach both, or the server row
// stays forever with no client able to see it.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const strip = (source) =>
  source.replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?\s*$/gm, '').replace(/^export /gm, '');

const layout = (width) => ({
  globalData: { navTop: 44, navHeight: 32, navRight: 96 },
  globalDataReady: true,
});

function page(mocks = {}) {
  const storage = new Map();
  const toasts = [];
  let definition;
  const wx = {
    getStorageSync: (key) => (storage.has(key) ? storage.get(key) : ''),
    setStorageSync: (key, value) => storage.set(key, value),
    removeStorageSync: (key) => storage.delete(key),
    getWindowInfo: () => ({ windowWidth: 390 }),
    createSelectorQuery: () => ({ select: () => ({ boundingClientRect: (callback) => (callback(null), { exec() {} }) }), exec() {} }),
    showToast: (options) => toasts.push(options.title),
    showLoading: () => undefined,
    hideLoading: () => undefined,
    navigateTo: () => undefined,
    ...(mocks.wx || {}),
  };
  const motion = {
    enterPage: () => undefined,
    retainLayerExit: () => undefined,
    cancelLayerExit: () => undefined,
    clearLayerMotion: () => undefined,
  };
  const api = {
    fetchAiModels: async () => ({ configured: true, model: 'deepseek-flash' }),
    sendAiMessage: async () => ({ data: {} }),
    deleteAiConversation: async () => ({ data: {} }),
    ...(mocks.api || {}),
  };
  const scope = {
    wx,
    getApp: () => layout(),
    Page: (value) => {
      definition = value;
    },
    setTimeout,
    clearTimeout,
    console,
    ...motion,
    ...api,
    ...mocks.globals,
  };
  for (const file of ['utils/motion', 'utils/format', 'utils/navigation', 'utils/theme_i18n', 'utils/ai_workspace', 'utils/auth_guard']) {
    const source = read(`${file}.js`);
    const names = [...source.matchAll(/export (?:const|function) (\w+)/g)].map((match) => match[1]);
    vm.runInNewContext(`${strip(source)};Object.assign(this, {${names.join(',')}});`, scope);
  }
  vm.runInNewContext(strip(read('pages/ai/index.js')), scope);
  return {
    toasts,
    storage,
    page: {
      ...definition,
      data: JSON.parse(JSON.stringify(definition.data)),
      setData(update, callback) {
        Object.assign(this.data, update);
        if (callback) callback();
      },
    },
  };
}

function withConversation(overrides = {}) {
  return {
    id: 'chat-1',
    title: '奖学金',
    createdAt: '2026-10-01T00:00:00.000Z',
    updatedAt: '2026-10-01T00:00:00.000Z',
    backendId: 'server-conversation',
    messages: [{ id: 'user-1', role: 'user', content: '奖学金怎么申请' }],
    ...overrides,
  };
}

test('deleting a conversation removes the server copy before the local cache', async () => {
  const calls = [];
  const harness = page({
    api: {
      deleteAiConversation: async (id) => {
        calls.push(id);
        return { data: {} };
      },
    },
  });
  const instance = harness.page;
  instance.data.conversations = [withConversation()];
  instance.data.activeConversationId = 'chat-1';
  instance.data.selectedConversationId = 'chat-1';
  await instance.confirmDeleteConversation();
  assert.deepEqual(calls, ['server-conversation']);
  assert.deepEqual(instance.data.conversations, []);
  assert.equal(instance.data.activeConversationId, '');
  assert.equal(harness.storage.get('aiConversations').length, 0);
});

test('a failed server delete keeps the conversation so the user can retry', async () => {
  const harness = page({
    api: {
      deleteAiConversation: async () => {
        throw new Error('offline');
      },
    },
  });
  const instance = harness.page;
  instance.data.conversations = [withConversation()];
  instance.data.selectedConversationId = 'chat-1';
  await instance.confirmDeleteConversation();
  assert.equal(instance.data.conversations.length, 1);
  assert.ok(harness.toasts.some((title) => title.includes('服务器删除失败')));
});

test('a conversation that never reached the server is deleted locally only', async () => {
  const calls = [];
  const harness = page({
    api: {
      deleteAiConversation: async (id) => {
        calls.push(id);
        return { data: {} };
      },
    },
  });
  const instance = harness.page;
  instance.data.conversations = [withConversation({ backendId: '' })];
  instance.data.selectedConversationId = 'chat-1';
  await instance.confirmDeleteConversation();
  assert.deepEqual(calls, []);
  assert.deepEqual(instance.data.conversations, []);
});
