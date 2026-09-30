const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]);
const files = walk(root).filter(p => /\.(js|json|wxml|wxss)$/.test(p));
const app = JSON.parse(read('app.json'));
const tabs = app.tabBar.list.map(t => t.pagePath);
function script(source) {
  return source.replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?\s*$/gm, '').replace(/^export\s+(?=(const|let|function|class)\b)/gm, '').replace(/^export default /gm, '');
}
function load(relative, mocks = {}) {
  let definition;
  const context = { ...require('./support/motion-context.cjs')(mocks), Page: x => { definition = x; }, Component: x => { definition = x; }, ...mocks };
  vm.runInNewContext(script(read(relative)), context, { filename: relative });
  return definition;
}
function instance(definition) {
  return { ...definition, ...definition.methods, data: JSON.parse(JSON.stringify(definition.data || {})), setData(update) { Object.assign(this.data, update); } };
}
test('drawer hides the custom tab bar and restores it on close', () => {
  const updates = [];
  const definition = load('components/radio-drawer/index.js', {
    getCurrentPages: () => [{ getTabBar: () => ({ setData: update => updates.push(update) }) }],
    wx: {}
  });
  const drawer = instance(definition);
  drawer.setTabBarVisibility(true);
  drawer.setTabBarVisibility(false);
  assert.equal(updates[0].drawerHidden, true);
  assert.equal(updates[1].drawerHidden, false);
});
test('drawer uses the measured top inset and no longer has a close control', () => {
  for (const width of [320, 390, 430, 768]) {
    const navRight = 102;
    const def = load('components/radio-drawer/index.js', {
      getApp: () => ({ globalData: { navTop: 48, navHeight: 32, navRight } }),
      wx: { getWindowInfo: () => ({ windowWidth: width }) }
    });
    const drawer = instance(def);
    def.lifetimes.attached.call(drawer);
    assert.equal(drawer.data.navTop, 48);
    assert.equal(drawer.data.navHeight, 32);
    assert.equal(Object.hasOwn(drawer.data, 'closeRight'), false);
  }
  assert.doesNotMatch(read('components/radio-drawer/index.wxml'), /drawer-close|drawer-toolbar/);
  assert.match(read('components/radio-drawer/index.wxml'), /drawer-mask[^>]*bindtap="close"/);
});
test('AI conversation sheets hide navigation and restore it on cancel or page exit', () => {
  const states = [];
  const page = instance(load('pages/ai/index.js', { setTimeout: () => 0 }));
  page.getTabBar = () => ({ setData: update => states.push(update.modalHidden) });
  page.setData({ conversations: [{ id: 'c1', title: '11', messages: [] }] });
  page.openConversationMenu({ currentTarget: { dataset: { id: 'c1' } } });
  assert.equal(states.at(-1), true);
  page.beginDeleteConversation();
  assert.equal(states.at(-1), true);
  page.closeConversationMenu();
  assert.equal(states.at(-1), false);
  page.toggleSidebar();
  page.openConversationMenu({ currentTarget: { dataset: { id: 'c1' } } });
  page.beginRenameConversation();
  page.closeConversationMenu();
  assert.equal(states.at(-1), true);
  page.onHide();
  assert.equal(states.at(-1), false);
  assert.equal(page.data.sidebarOpen, false);
  assert.equal(page.data.conversationMenuOpen, false);
});
test('AI deletion closes the sheet in both active and inactive conversation branches', () => {
  for (const activeId of ['c1', 'c2']) {
    const states = [];
    const page = instance(load('pages/ai/index.js', {
      setTimeout: () => 0,
      formatTime: () => '今天',
      wx: { setStorageSync() {}, removeStorageSync() {} }
    }));
    page.getTabBar = () => ({ setData: update => states.push(update.modalHidden) });
    page.setData({ conversations: [{id:'c1',title:'11',messages:[]},{id:'c2',title:'22',messages:[]}], activeConversationId:activeId });
    page.openConversationMenu({ currentTarget: { dataset: { id: 'c1' } } });
    page.beginDeleteConversation();
    page.confirmDeleteConversation();
    assert.equal(page.data.conversations.length, 1);
    assert.equal(page.data.conversationMenuOpen, false);
    assert.equal(states.at(-1), false);
  }
});
test('notification load decorates actual actor data and marks all read without dropping the filter', async () => {
  let marked = 0;
  const def = load('pages/profile/notifications/index.js', {
    wx: { getStorageSync: () => 'account-a' },
    requireLoginPage: () => true,
    getNotifications: async () => ({ unreadCount: 2, items: [
      { id: 'n1', type: 'like', title: '点赞', actorAlias: '同学', isRead: false },
      { id: 'n2', type: 'reply', title: '回复', actorAvatarUrl: '/avatar.png', isRead: false }
    ] }),
    markAllNotificationsRead: async () => { marked++; }
  });
  const page = instance(def);
  await page.loadData();
  assert.equal(page.data.items[0].noticeIcon, 'heart');
  assert.equal(page.data.items[0].actorInitial, '同');
  page.switchFilter({ currentTarget: { dataset: { filter: 'replies' } } });
  await page.markAllRead();
  assert.equal(marked, 1);
  assert.equal(page.data.unreadCount, 0);
  assert.equal(page.data.displayedItems.length, 1);
  assert.equal(page.data.displayedItems[0].actorAvatarUrl, '/avatar.png');
  assert.equal(page.data.displayedItems[0].isRead, true);
  assert.equal(page.data.markingRead, false);
});
test('both inbox refreshers stop even when a load fails', async () => {
  for (const route of ['notifications', 'conversations']) {
    const page = instance(load(`pages/profile/${route}/index.js`));
    page.loadData = async () => { throw new Error('network'); };
    await assert.rejects(page.refreshList(), /network/);
    assert.equal(page.data.refreshing, false);
  }
});
test('recipient search ignores stale results and a closed picker', async () => {
  const requests = [];
  const page = instance(load('pages/profile/conversations/index.js', {
    searchUsers: () => new Promise(resolve => requests.push(resolve))
  }));
  page.openNewMessage();
  page.onRecipientInput({ detail: { value: 'first' } });
  const first = page.searchRecipients();
  page.onRecipientInput({ detail: { value: 'second' } });
  const second = page.searchRecipients();
  requests[1]([{ id: 'u2' }]);
  await second;
  requests[0]([{ id: 'u1' }]);
  await first;
  assert.equal(page.data.recipients[0].id, 'u2');
  const third = page.searchRecipients();
  page.closeNewMessage();
  requests[2]([{ id: 'u3' }]);
  await third;
  assert.equal(page.data.recipients[0].id, 'u2');
  assert.equal(page.data.recipientLoading, false);
});
test('new message uses the existing direct-conversation API and suppresses duplicate creates', async () => {
  const targets = [], navigations = [];
  let complete;
  const page = instance(load('pages/profile/conversations/index.js', {
    createDirectConversation: payload => { targets.push(payload.targetUserId); return new Promise(resolve => { complete = resolve; }); },
    wx: { navigateTo: ({ url }) => navigations.push(url) }
  }));
  page.openNewMessage();
  page.setData({ recipients: [{ id: 'u7', nickname: '同学', avatarUrl: '' }] });
  const event = { currentTarget: { dataset: { index: 0 } } };
  const first = page.startConversation(event);
  await page.startConversation(event);
  complete({ id: 'chat7' });
  await first;
  assert.equal(targets.length, 1);
  assert.equal(targets[0], 'u7');
  assert.match(navigations[0], /id=chat7.*peerUserId=u7/);
  assert.equal(page.data.newMessageOpen, false);
  assert.equal(page.data.creatingConversation, false);
});
test('a swipe or long press cannot accidentally open the chat', () => {
  const navigations = [];
  const page = instance(load('pages/profile/conversations/index.js', { wx: { navigateTo: args => navigations.push(args) } }));
  page.setData({ conversations: [{ id: 'c1', name: '同学', offsetX: 0 }] });
  const event = { currentTarget: { dataset: { index: 0 } } };
  page._rowMoved = true;
  page.openChat(event);
  page._rowLongPressed = true;
  page.openChat(event);
  assert.equal(navigations.length, 0);
  page.openChat(event);
  assert.equal(navigations.length, 1);
});
test('all routes, components, imports and JavaScript parse', () => {
  for (const p of app.pages) for (const ext of ['.js', '.json', '.wxml']) assert.ok(fs.existsSync(path.join(root, p + ext)), p + ext);
  for (const p of files) {
    const s = fs.readFileSync(p, 'utf8');
    if (p.endsWith('.json')) JSON.parse(s);
    if (p.endsWith('.js')) {
      new vm.Script(script(s), { filename: p });
      for (const m of s.matchAll(/from\s+['"](\.[^'"]+)['"]/g)) assert.ok(fs.existsSync(path.resolve(path.dirname(p), m[1] + '.js')), p + ': ' + m[1]);
    }
    if (p.endsWith('.wxss')) for (const m of s.matchAll(/@import\s+['"]([^'"]+)['"]/g)) assert.ok(fs.existsSync(path.resolve(path.dirname(p), m[1])), p + ': ' + m[1]);
  }
  for (const component of Object.values(app.usingComponents)) assert.ok(fs.existsSync(path.join(root, component + '.json')));
});
test('WXML is balanced and every event has a real handler', () => {
  for (const p of files.filter(p => p.endsWith('.wxml'))) {
    const source = fs.readFileSync(p, 'utf8').replace(/<!--[\s\S]*?-->/g, '');
    const js = fs.readFileSync(p.replace('.wxml', '.js'), 'utf8');
    const stack = [];
    for (const m of source.matchAll(/<\/?[\w-]+\b(?:[^"'<>]|"[^"]*"|'[^']*')*>/g)) {
      const tag = m[0], name = tag.match(/^<\/?([\w-]+)/)[1];
      if (tag.startsWith('</')) assert.equal(stack.pop(), name, p + ': ' + tag);
      else if (!tag.endsWith('/>')) stack.push(name);
    }
    assert.deepEqual(stack, [], p);
    for (const m of source.matchAll(/(?:bind|catch)(?::)?[\w-]+="([A-Za-z_$][\w$]*)"/g)) assert.match(js, new RegExp('\\b' + m[1] + '\\s*\\('), p + ': ' + m[1]);
  }
});
test('five tabs, safe-area inset, and settings-only language/campus login', () => {
  assert.equal(app.tabBar.custom, true);
  assert.deepEqual(tabs, ['pages/treehole/index', 'pages/campus/index', 'pages/ai/index', 'pages/profile/notifications/index', 'pages/profile/conversations/index']);
  assert.match(read('custom-tab-bar/index.wxss'), /env\(safe-area-inset-bottom\)/);
  assert.doesNotMatch(read('components/radio-drawer/index.wxml'), /bindtap="goCampus"/);
  assert.doesNotMatch(read('pages/campus/index.wxml'), /openIdsLogin|auth-center/);
  assert.match(read('pages/profile/settings/index.wxml'), /pages\/campus\/auth-center\/index/);
  assert.match(read('pages/profile/settings/index.wxml'), /bindchange="onLanguageChange"/);
  for (const p of files.filter(p => p.endsWith('.wxml'))) assert.doesNotMatch(fs.readFileSync(p, 'utf8'), /bindtap="onLangTap"/);
  for (const p of files.filter(p => p.endsWith('.js'))) {
    const source = fs.readFileSync(p, 'utf8');
    for (const m of source.matchAll(/wx\.(navigateTo|redirectTo|switchTab)\(\{\s*url:\s*['"]\/([^'"]+)['"]/g)) {
      const route = m[2].split('?')[0];
      if (m[1] === 'switchTab') assert.ok(tabs.includes(route), p + ': non-tab switch');
      else assert.ok(!tabs.includes(route), p + ': navigateTo on tab');
    }
  }
});
test('tab buttons suppress native touch highlight without removing their own feedback', () => {
  const styles = read('custom-tab-bar/index.wxss');
  assert.match(styles, /\.tab\s*\{[^}]*-webkit-tap-highlight-color:\s*transparent\s*;/);
  assert.match(styles, /\.selection-surface\s*\{[^}]*background:\s*var\(--app-accent-soft\)/);
  assert.match(styles, /\.pressed \.tab-symbol\s*\{[^}]*transform:/);
  assert.match(styles, /\.tab:focus-visible \.tab-symbol\s*\{[^}]*outline:/);
  assert.match(read('custom-tab-bar/index.wxml'), /hover-class="pressed"/);
});
test('tab navigation syncs selected state and switches immediately without reopening the selected tab', () => {
  const calls = [];
  const def = load('custom-tab-bar/index.js', { wx: { switchTab: x => { calls.push(x.url); if (x.success) x.success(); } }, getCurrentPages: () => [{ route: tabs[3] }], getDisplayMode: () => 'dark', resolveDisplayMode: x => x, getLanguage: () => 'en', setTimeout, clearTimeout });
  const tab = instance(def);
  tab.sync();
  assert.equal(tab.data.selected, tabs[3]);
  assert.equal(tab.data.themeClass, 'theme-reference color-mode-dark');
  assert.equal(tab.data.english, true);
  tab.navigate({ currentTarget: { dataset: { path: tabs[3] } } });
  tab.navigate({ currentTarget: { dataset: { path: tabs[4] } } });
  assert.deepEqual(calls, ['/' + tabs[4]]);
  assert.equal(tab.data.navigating, false);
});
test('tab motion survives the destination handoff and replays when returning to a cached tab', () => {
  let route = tabs[0], nextTimer = 0;
  const calls = [], timers = new Map();
  const def = load('custom-tab-bar/index.js', {
    wx: {switchTab: options => calls.push(options)},
    getCurrentPages: () => [{route}], getDisplayMode: () => 'light', resolveDisplayMode: x => x, getLanguage: () => 'zh',
    setTimeout: fn => {timers.set(++nextTimer,fn); return nextTimer;}, clearTimeout: id => timers.delete(id)
  });
  const home = instance(def), ai = instance(def);
  home.sync();
  home.navigate({currentTarget:{dataset:{path:tabs[2]}}});
  home.sync();
  home.navigate({currentTarget:{dataset:{path:tabs[4]}}});
  assert.equal(calls.length, 1, 'repeated taps remain locked even during a theme sync');
  assert.equal(home.data.selected, tabs[0]);
  def.pageLifetimes.hide.call(home);
  route = tabs[2];
  ai.sync();
  assert.equal(ai.data.activeIndex, 2);
  assert.equal(ai.data.motionFrom, 0);
  assert.equal(ai.data.animating, true);
  const timer = ai._motionTimer;
  ai.sync();
  assert.equal(ai._motionTimer, timer, 'repeated show/theme sync must not replay the arrival');
  calls[0].success();
  ai.navigate({currentTarget:{dataset:{path:tabs[0]}}});
  def.pageLifetimes.hide.call(ai);
  assert.equal(timers.has(timer), false);
  route = tabs[0];
  home.sync();
  assert.equal(home.data.animating, true);
  assert.equal(home.data.motionFrom, 2);
  assert.equal(home.data.activeIndex, 0);
  calls[1].success();
  timers.get(home._motionTimer)();
  assert.equal(home.data.animating, false);
});
test('failed tab navigation preserves selection and does not leak an arrival into a later visit', () => {
  let route = tabs[1], request;
  const def = load('custom-tab-bar/index.js', {
    wx: {switchTab: options => {request=options;}}, getCurrentPages: () => [{route}],
    getDisplayMode: () => 'dark', resolveDisplayMode: x => x, getLanguage: () => 'zh', setTimeout, clearTimeout
  });
  const source = instance(def);
  source.sync();
  source.navigate({currentTarget:{dataset:{path:tabs[3]}}});
  request.fail();
  assert.equal(source.data.selected,tabs[1]);
  assert.equal(source.data.activeIndex,1);
  assert.equal(source.data.navigating,false);
  route=tabs[3];
  const destination=instance(def);
  destination.sync();
  assert.equal(destination.data.activeIndex,3);
  assert.equal(destination.data.animating,false);
});
test('AI draft sends and replies inside the root AI tab without opening a new page', async () => {
  const requests = [];
  const storage = {};
  const ai = instance(load('pages/ai/index.js', {
    wx: {
      getStorageSync: key => storage[key],
      setStorageSync: (key, value) => { storage[key] = value; },
      showToast() {},
      navigateTo() { throw new Error('AI chat must stay on the root tab'); },
      createSelectorQuery: () => ({ select: () => ({ boundingClientRect: () => ({ exec() {} }) }) })
    },
    requireLoginPage: () => true,
    sendAiMessage: async (content, options) => {
      requests.push({ content, options });
      return { data: { answer: '这是当前页面里的回答。', references: [] } };
    },
    truncate: value => String(value).slice(0, 30),
    formatTime: () => '刚刚',
    openAppTarget: () => false
  }));
  ai.data.configured = true;
  ai.data.configLoading = false;
  ai.data.draft = '  课表 & timetable?  ';
  await ai.submitQuestion();
  assert.equal(requests[0].content, '课表 & timetable?');
  assert.deepEqual(Array.from(ai.data.messages, item => item.role), ['user', 'assistant']);
  assert.equal(ai.data.messages[1].content, '这是当前页面里的回答。');
  assert.equal(ai.data.draft, '');
  assert.equal(ai.data.conversations.length, 1);
});
test('light and dark tokens retain legible primary and secondary text', () => {
  const tokens = read('styles/tokens.wxss');
  assert.match(tokens, /--font-body:.*sans-serif/);
  assert.doesNotMatch(tokens, /Times New Roman|STZhongsong/);
  const luminance = hex => {
    const channels = hex.match(/\w\w/g).map(x => parseInt(x, 16) / 255).map(x => x <= .04045 ? x / 12.92 : ((x + .055) / 1.055) ** 2.4);
    return channels[0] * .2126 + channels[1] * .7152 + channels[2] * .0722;
  };
  const blocks = [...tokens.matchAll(/\{([^}]+)\}/g)].map(m => Object.fromEntries([...m[1].matchAll(/(--[\w-]+):\s*#([\da-f]{6})/g)].map(x => [x[1], x[2]])));
  const pairs = blocks.flatMap(b => ['--app-text-primary', '--app-text-secondary', '--app-text-tertiary'].map(k => [b['--app-background'], b[k]]));
  for (const [bg, fg] of pairs) {
    const a = luminance(bg), b = luminance(fg);
    assert.ok((Math.max(a, b) + .05) / (Math.min(a, b) + .05) >= 4.5, bg + '/' + fg);
  }
  const dark = blocks.find(block => block['--app-background'] === '171b21');
  assert.ok(dark);
  assert.notEqual(dark['--app-background'], dark['--app-surface']);
  assert.notEqual(dark['--app-surface'], dark['--app-card']);
  assert.notEqual(dark['--app-card'], dark['--app-control']);
  for (const surface of ['--app-background', '--app-surface', '--app-card', '--app-control']) {
    for (const text of ['--app-text-primary', '--app-text-secondary', '--app-text-tertiary', '--app-accent']) {
      const a = luminance(dark[surface]), b = luminance(dark[text]);
      assert.ok((Math.max(a, b) + .05) / (Math.min(a, b) + .05) >= 4.5, surface + '/' + text);
    }
  }
});
