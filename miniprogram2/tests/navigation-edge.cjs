const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const tap = tab => ({ currentTarget: { dataset: { tab } } });

function hostFor(file, wx = {}) {
  let definition;
  vm.runInNewContext(read(file).replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?\s*$/gm, ''), {
    ...require('./support/motion-context.cjs')(),
    sharePost() {}, wx,
    Page: value => { definition = value; },
    Component: value => { definition = value; }
  });
  return { ...definition, ...definition.methods, data: JSON.parse(JSON.stringify(definition.data)),
    setData: require('./support/set-data.cjs') };
}

function home() {
  const queries = [], scrolls = [];
  const host = hostFor('pages/treehole/index.js', {
    createSelectorQuery() {
      const query = require('./support/selector-query.cjs')();
      const selectors = [];
      query.select = function (selector) { selectors.push(selector); return this; };
      query.exec = callback => queries.push({ selectors, callback });
      return query;
    }
  });
  function resolve(index, left, right, scrollLeft, itemLeft, itemRight) {
    queries[index].callback([{ left, right, scrollLeft, node: { scrollTo: value => scrolls.push(value) } }, { left: itemLeft, right: itemRight }]);
  }
  return { host, queries, scrolls, resolve };
}

test('tapping a fully visible college tab preserves the current index scroll position', () => {
  const { host, queries, scrolls, resolve } = home();
  host.onHomeTabTap(tap('colleges'));
  assert.equal(host.data.activeHomeTab, 'colleges');
  assert.deepEqual(queries[0].selectors, ['.feed-tab-scroll', '#home-tab-colleges']);
  resolve(0, 0, 346, 0, 88, 176);
  assert.equal(scrolls.length, 0);
  const scroll = read('pages/treehole/index.wxml').match(/<scroll-view class="feed-tab-scroll"[^>]*>/)[0];
  assert.doesNotMatch(scroll, /scroll-into-view|scroll-left/);
});

test('partially clipped tabs scroll only the missing distance using the live scroll offset', () => {
  for (const [right, scrollLeft, itemLeft, itemRight, expected] of [
    [346, 0, 264, 352, 6], [244, 0, 176, 264, 20],
    [174, 180, -4, 84, 176], [346, 54, 298, 386, 94]
  ]) {
    const { host, scrolls, resolve } = home();
    host.onHomeTabTap(tap('clubs'));
    resolve(0, 0, right, scrollLeft, itemLeft, itemRight);
    assert.equal(scrolls.length, 1);
    assert.equal(scrolls[0].left, expected);
    assert.equal(scrolls[0].animated, true);
    assert.equal(scrolls[0].duration, 360);
  }
});

test('manual scrolling does not prevent a later correction to the same pixel target', () => {
  const { host, scrolls, resolve } = home();
  host.onHomeTabTap(tap('clubs')); resolve(0, 0, 346, 0, 264, 352);
  host.onHomeTabTap(tap('colleges')); resolve(1, 0, 346, 6, 82, 170);
  host.onHomeTabTap(tap('clubs')); resolve(2, 0, 346, 0, 264, 352);
  assert.deepEqual(scrolls.map(value => value.left), [6, 6]);
});

test('stale tab measurements cannot scroll a newer selection, search, or an exited page', () => {
  for (const cancel of [host => host.onHomeTabTap(tap('organizations')), host => { host.data.searchOpen = true; }, host => host.onHide(), host => host.onUnload()]) {
    const { host, scrolls, resolve } = home();
    host.onHomeTabTap(tap('clubs')); cancel(host); resolve(0, 0, 244, 0, 264, 352);
    assert.equal(scrolls.length, 0);
  }
});

test('drawer swipe listeners never catch child taps or touch events and the panel stays above its mask', () => {
  const template = read('components/radio-drawer/index.wxml');
  assert.doesNotMatch(template, /catch(?:tap|touchstart|touchend)/);
  assert.match(template, /bindtouchstart="onPanelTouchStart" bindtouchend="onPanelTouchEnd" bindtouchcancel="onPanelTouchCancel"/);
  assert.match(template, /drawer-mask[^>]*bindtap="close"/);
  const css = read('components/radio-drawer/index.wxss');
  assert.match(css, /\.drawer-mask \{[^}]*z-index:0;/);
  assert.match(css, /\.drawer-panel \{[^}]*z-index:1;/);
});

test('every drawer navigation entry closes the drawer and opens its registered destination', () => {
  const registered = JSON.parse(read('app.json')).pages;
  const calls = [];
  const host = hostFor('components/radio-drawer/index.js', {
    navigateTo: value => calls.push({ type: 'page', ...value }),
    switchTab: value => calls.push({ type: 'tab', ...value })
  });
  host.triggerEvent = type => calls.push({ type });
  for (const [method, type, url] of [
    ['goProfile', 'page', '/pages/profile/index'], ['goFavorites', 'page', '/pages/profile/favorites/index'],
    ['goHistory', 'page', '/pages/ai/history/index'], ['goClubs', 'page', '/pages/clubs/index'],
    ['goReports', 'page', '/pages/profile/my-reports/index'], ['goMessages', 'tab', '/pages/profile/conversations/index'],
    ['goSettings', 'page', '/pages/profile/settings/index'], ['goMailbox', 'page', '/pages/profile/feedback/index'],
    ['goAdmin', 'page', '/pages/admin/index']
  ]) {
    calls.length = 0; host[method]();
    assert.deepEqual(calls, [{ type: 'close' }, { type, url }]);
    assert.ok(registered.includes(url.slice(1)));
  }
  calls.length = 0; host.data.conversations = [{ id: 'c1', name: '同学', peerUserId: 'u1' }];
  host.goConversation({ currentTarget: { dataset: { index: 0 } } });
  assert.equal(calls[0].type, 'close');
  assert.ok(calls[1].url.startsWith('/pages/profile/chat/index?id=c1&'));
});

test('ordinary taps, vertical scrolling and cancelled gestures do not dismiss the drawer', () => {
  const host = hostFor('components/radio-drawer/index.js');
  let closed = 0; host.triggerEvent = () => closed++;
  const start = () => host.onPanelTouchStart({ touches: [{ clientX: 200, clientY: 200 }] });
  const end = (clientX, clientY) => host.onPanelTouchEnd({ changedTouches: [{ clientX, clientY }] });
  start(); end(200, 200); start(); end(190, 320); start(); host.onPanelTouchCancel(); end(100, 210);
  assert.equal(closed, 0);
  start(); end(100, 210); assert.equal(closed, 1);
});

test('drawer touch events bubbling to the feed cannot trigger its edge-opening gesture', () => {
  const { host } = home(); host.data.drawerOpen = true;
  host.openDrawer = () => assert.fail('drawer gesture reached the feed');
  host.onTouchStart({ touches: [{ clientX: 10, clientY: 200 }] });
  host.onTouchEnd({ changedTouches: [{ clientX: 100, clientY: 200 }] });
  assert.equal(host._touchStart, null);
});
