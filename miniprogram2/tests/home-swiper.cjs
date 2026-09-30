const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const tap = tab => ({ currentTarget: { dataset: { tab } } });
const swipe = (current, source = 'touch', id = 'home-pager') => ({ target: { id }, detail: { current, source } });
const finishSwipe = (host, ...args) => {
  host.onHomeSwipeChange(swipe(...args));
  host.onHomeSwipeFinish(swipe(...args));
};
const scroll = (tab, scrollTop) => ({ ...tap(tab), detail: { scrollTop } });
const result = (id, page = 1, hasMore = false) => ({ items: [{ id }], page, total: 30, hasMore });
const tick = () => new Promise(setImmediate);

function setup(overrides = {}) {
  let definition;
  const calls = [];
  const scope = {
    Page: value => { definition = value; }, sharePost() {},
    getPostsPage: params => new Promise((resolve, reject) => calls.push({ params, resolve, reject })),
    attachDisplayImages: value => value, hydrateDisplayImages: async () => ({}), applyHydratedDisplayImages: posts => posts,
    wx: { createSelectorQuery: require('./support/selector-query.cjs'), stopPullDownRefresh() {} }, ...overrides
  };
  vm.runInNewContext(read('pages/treehole/index.js').replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?\s*$/gm, ''), scope);
  const host = { ...definition, data: JSON.parse(JSON.stringify(definition.data)), setData: require('./support/set-data.cjs') };
  return { host, calls };
}

test('five native swipe panels stay mounted, noncircular, with independent scroll and refresh', () => {
  const wxml = read('pages/treehole/index.wxml');
  assert.match(wxml, /<swiper id="home-pager"[^>]*current="{{activeHomeTabIndex}}"[^>]*duration="420"[^>]*circular="{{false}}"/);
  assert.match(wxml, /<swiper-item wx:for="{{homeTabs}}"[^>]*wx:key="value"/);
  assert.doesNotMatch(wxml.match(/<swiper-item[^>]*>/)[0], /wx:if/);
  assert.match(wxml, /class="feed-list" data-tab="{{feed.value}}"/);
  assert.match(wxml, /list-key="{{feed.value}}"/);
  assert.match(wxml, /id="feed-top-{{feed.value}}"/);
  assert.doesNotMatch(wxml, /contentMotion|disable-touch/);
});

test('a quick swipe never rewrites current or starts a request before native settling finishes', () => {
  const { host, calls } = setup();
  const patches = []; const setData = host.setData;
  host.setData = function(patch, callback) { patches.push(patch); setData.call(this, patch, callback); };
  host.onHomePagerTouchStart();
  host.onHomeSwipeChange(swipe(1));
  assert.equal(patches.length, 0);
  host.onHomePagerTouchEnd();
  assert.equal(host.data.activeHomeTab, 'hot');
  assert.equal(calls.length, 0);
  host.onHomeSwipeFinish(swipe(1));
  assert.equal(host.data.activeHomeTab, 'colleges');
  assert.equal(patches.filter(patch => Object.hasOwn(patch, 'activeHomeTabIndex')).length, 1);
  patches.length = 0;
  host.onHomeSwipeChange(swipe(2));
  assert.equal(calls.length, 0);
  assert.equal(patches.length, 0);
  host.onHomeSwipeFinish(swipe(2));
  assert.equal(host.data.activeHomeTab, 'latest');
  assert.equal(calls.length, 1);
});

test('cancelled swipes and programmatic echoes do not select the attempted next panel', () => {
  const { host, calls } = setup();
  host.onHomeSwipeChange(swipe(1));
  host.onHomeSwipeChange(swipe(0));
  host.onHomeSwipeFinish(swipe(0));
  assert.equal(host.data.activeHomeTab, 'hot');
  host.onHomeSwipeFinish(swipe(1, ''));
  assert.equal(host.data.activeHomeTab, 'hot');
  assert.equal(calls.length, 0);
});

test('rapid consecutive swipes ignore old finish events while the next gesture owns the pager', () => {
  const { host, calls } = setup();
  host.onHomeSwipeChange(swipe(1));
  host.onHomePagerTouchStart();
  host.onHomeSwipeFinish(swipe(1));
  assert.equal(host.data.activeHomeTab, 'hot');
  host.onHomeSwipeChange(swipe(2));
  host.onHomePagerTouchEnd();
  host.onHomeSwipeFinish(swipe(1));
  assert.equal(host.data.activeHomeTab, 'hot');
  host.onHomeSwipeFinish(swipe(2));
  assert.equal(host.data.activeHomeTab, 'latest');
  assert.equal(calls.length, 1);
});

test('an index tap supersedes a pending swipe and lifecycle cleanup rejects its finish', () => {
  const { host } = setup();
  host.onHomeSwipeChange(swipe(1));
  host.onHomeTabTap(tap('organizations'));
  host.onHomeSwipeFinish(swipe(1));
  assert.equal(host.data.activeHomeTab, 'organizations');
  host.onHomeSwipeChange(swipe(3)); host.onHide(); host.onHomeSwipeFinish(swipe(3));
  assert.equal(host.data.activeHomeTab, 'organizations');
  host.onHomeSwipeChange(swipe(3)); host.onUnload(); host.onHomeSwipeFinish(swipe(3));
  assert.equal(host.data.activeHomeTab, 'organizations');
});

test('recommendation-college round trips remain selectable during a pending feed request', async () => {
  const { host, calls } = setup();
  const pending = host.fetchPosts();
  for (let i = 0; i < 3; i++) {
    finishSwipe(host, 1);
    assert.equal(host.data.activeHomeTab, 'colleges');
    finishSwipe(host, 0);
    assert.equal(host.data.activeHomeTab, 'hot');
  }
  assert.equal(calls.length, 1);
  calls[0].resolve(result('recommended')); await pending;
  assert.equal(host.getFeed('hot').posts[0].id, 'recommended');
});

test('index taps and touch swipes share selection without programmatic feedback loops', () => {
  const { host, calls } = setup();
  host.onHomeTabTap(tap('colleges')); assert.equal(host.data.activeHomeTabIndex, 1);
  finishSwipe(host, 2, ''); assert.equal(host.data.activeHomeTab, 'colleges');
  finishSwipe(host, 2); assert.equal(host.data.activeHomeTab, 'latest'); assert.equal(calls.length, 1);
  finishSwipe(host, 2); host.onHomeTabTap(tap('latest')); assert.equal(calls.length, 1);
  finishSwipe(host, 1, 'touch', 'post-media'); assert.equal(host.data.activeHomeTab, 'latest');
  finishSwipe(host, 5); finishSwipe(host, -1); assert.equal(host.data.activeHomeTab, 'latest');
});

test('search and drawer lock content swiping without discarding the active panel', () => {
  for (const key of ['searchOpen', 'drawerOpen']) {
    const { host, calls } = setup(); host.data[key] = true;
    finishSwipe(host, 2); host.onHomeTabTap(tap('colleges'));
    assert.equal(host.data.activeHomeTab, 'hot'); assert.equal(calls.length, 0);
  }
  assert.match(read('pages/treehole/index.wxss'), /\.home-pager\.pager-locked \{ pointer-events:none; \}/);
});

test('requests are lazy, paginated, and independent when swiping while loading', async () => {
  const { host, calls } = setup(); const first = host.fetchPosts();
  assert.equal(calls.length, 1); assert.equal(calls[0].params.limit, 10);
  finishSwipe(host, 1); assert.equal(calls.length, 1);
  finishSwipe(host, 2); assert.equal(calls.length, 2); assert.equal(calls[1].params.sort, 'latest');
  finishSwipe(host, 0); assert.equal(calls.length, 2);
  calls[1].resolve(result('new')); await tick(); calls[0].resolve(result('hot', 1, true)); await first;
  assert.equal(host.getFeed('hot').posts[0].id, 'hot'); assert.equal(host.getFeed('latest').posts[0].id, 'new');
  finishSwipe(host, 2); finishSwipe(host, 0); assert.equal(calls.length, 2);
  host.onReachBottom(tap('latest')); assert.equal(calls.length, 2);
  const next = host.onReachBottom(tap('hot')); assert.equal(calls[2].params.page, 2);
  calls[2].resolve(result('hot2', 2)); await next;
  assert.equal(host.getFeed('hot').posts.length, 2); assert.equal(host.getFeed('latest').page, 2);
  finishSwipe(host, 3); finishSwipe(host, 4); await host.refreshFeed();
  assert.equal(calls.length, 3); assert.equal(host.getFeed().posts.length, 0);
});

test('refresh completion stays with its origin after swiping to another feed', async () => {
  const { host, calls } = setup(); host.setFeedState('hot', { initialized: true, posts: [{ id: 'old' }] });
  const refresh = host.refreshFeed(); finishSwipe(host, 2);
  assert.equal(host.getFeed('hot').refreshTriggered, true); assert.equal(host.getFeed('latest').refreshTriggered, false);
  calls[0].resolve(result('refreshed')); await refresh;
  assert.equal(host.data.activeHomeTab, 'latest'); assert.equal(host.getFeed('hot').refreshTriggered, false);
  assert.equal(host.getFeed('hot').posts[0].id, 'refreshed'); assert.equal(host.getFeed('latest').posts.length, 0);
  calls[1].resolve(result('latest')); await tick(); assert.equal(host.getFeed().posts[0].id, 'latest');
});

test('an older response cannot overwrite a newer refresh within the same panel', async () => {
  const { host, calls } = setup(); const old = host.fetchPosts(); const fresh = host.refreshFeed();
  calls[1].resolve(result('fresh')); await fresh; calls[0].resolve(result('old')); await old;
  assert.equal(host.getFeed().posts[0].id, 'fresh'); assert.equal(host.getFeed().refreshTriggered, false);
});

test('college selection survives leaving the panel and rejects the previous college response', async () => {
  const { host, calls } = setup(); finishSwipe(host, 1);
  host.selectCollege({ currentTarget: { dataset: { college: { id: 'cs', sectionName: '计算机学院' } } } });
  finishSwipe(host, 3); finishSwipe(host, 1); assert.equal(calls.length, 1);
  assert.equal(host.getFeed().activeCollege.id, 'cs');
  host.selectCollege({ currentTarget: { dataset: { college: { id: 'ee', sectionName: '电子学院' } } } });
  assert.equal(calls[1].params.sectionId, 'ee');
  calls[1].resolve(result('ee')); await tick(); calls[0].resolve(result('cs')); await tick();
  assert.equal(host.getFeed().posts[0].id, 'ee'); assert.equal(host.getFeed().activeCollege.id, 'ee');
});

test('each panel retains its scroll position; background scrolls cannot collapse the active header', () => {
  const { host } = setup(); host.setFeedState('latest', { initialized: true });
  host.onScroll(scroll('hot', 0)); host.onScroll(scroll('hot', 1000));
  finishSwipe(host, 2); host.onScroll(scroll('latest', 20));
  finishSwipe(host, 0); assert.equal(host._lastScrollTop, 1000); assert.equal(host.data.showBackToTop, true);
  host.data.headerCollapsed = true; host.onScroll(scroll('latest', 0)); assert.equal(host.data.headerCollapsed, true);
  host.backToTop(); assert.equal(host.getFeed('hot').feedScrollIntoView, 'feed-top-hot');
  assert.equal(host.getFeed('latest').feedScrollIntoView, ''); assert.equal(host._feedScrollTops.hot, 0);
});

test('content swipes never also run the homepage edge gesture', () => {
  const { host } = setup(); host.openDrawer = () => assert.fail('drawer opened during content swipe');
  host.onHomePagerTouchStart(); host.onTouchStart({ touches: [{ clientX: 10, clientY: 240 }] });
  host.onHomePagerTouchEnd(); host.onTouchEnd({ changedTouches: [{ clientX: 160, clientY: 242 }] });
  assert.equal(host._touchStart, null); assert.equal(host._homePagerTouch, false);
});

test('background load failures stay on their own panel and do not reload automatically on return', async () => {
  const { host, calls } = setup(); const pending = host.fetchPosts(); finishSwipe(host, 3);
  calls[0].reject(new Error('Offline')); await pending;
  assert.equal(host.getFeed().errorMessage, ''); assert.equal(host.getFeed('hot').errorMessage, 'Offline');
  finishSwipe(host, 0); assert.equal(calls.length, 1);
  const retry = host.retryFeed(tap('hot')); calls[1].resolve(result('recovered')); await retry;
  assert.equal(host.getFeed().errorMessage, '');
});

test('late likes update the originating post across panels without overwriting appended posts', async () => {
  let finish;
  const { host } = setup({ togglePostLikeInList: posts => new Promise(resolve => { finish = () => resolve([{ ...posts[0], liked: true, isLiked: true, likeCount: 1 }]); }) });
  host.setFeedState('hot', { initialized: true, posts: [{ id: 'shared', likeCount: 0 }] });
  host.setFeedState('latest', { initialized: true, posts: [{ id: 'shared', likeCount: 0 }, { id: 'latest-only' }] });
  const pending = host.togglePostLike({ detail: { listKey: 'hot', index: 0 } });
  finishSwipe(host, 2); host.setFeedState('hot', { posts: [{ id: 'shared', likeCount: 0 }, { id: 'appended' }] });
  finish(); await pending;
  assert.equal(host.getFeed('hot').posts.length, 2); assert.equal(host.getFeed('hot').posts[0].liked, true);
  assert.equal(host.getFeed('latest').posts[0].liked, true); assert.equal(host.getFeed('latest').posts[1].id, 'latest-only');
});

test('page exit drops pending responses without writing into detached panels', async () => {
  const { host, calls } = setup(); const pending = host.fetchPosts(); host.onUnload();
  host.setData = () => assert.fail('detached page update'); calls[0].resolve(result('late')); await pending;
});
