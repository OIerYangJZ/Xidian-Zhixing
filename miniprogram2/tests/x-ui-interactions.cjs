const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const strip = s => s.replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?\s*$/gm, '').replace(/^export /gm, '');
function load(file, mocks = {}) {
  let definition;
  vm.runInNewContext(strip(read(file)), { ...require('./support/motion-context.cjs')(mocks), Component: x => {definition=x;}, Page: x => {definition=x;}, App: x => {definition=x;}, ...mocks, wx: { createSelectorQuery: require('./support/selector-query.cjs'), ...mocks.wx } });
  return definition;
}
function loadFunction(file, name) {
  const scope = {};
  vm.runInNewContext(strip(read(file)) + ';this.result=' + name, scope);
  return scope.result;
}
const compactCount = loadFunction('utils/compact_count.js', 'compactCount');
test('long metric counts stay compact without rounding 999 into the next unit', () => {
  for (const [n, expected] of [[0,'0'],[999,'999'],[1000,'1K'],[1999,'1.9K'],[999999,'999K'],[1000000,'1M'],[999999999,'999M'],[1250000000,'1.2B']]) assert.equal(compactCount(n),expected);
});
test('post actions keep original event payloads, and counts update after mutations', () => {
  const events=[];
  let sheet;
  const def=load('components/post-row/index.js',{compactCount,wx:{showActionSheet:x=>{sheet=x;}}});
  const row={...def.methods,data:{item:{id:'p1',liked:false,favorited:false,likeCount:999,viewCount:1250000},index:3,listKey:'favoritePosts'},setData(x){Object.assign(this.data,x);},triggerEvent:(name,detail)=>events.push({name,detail})};
  def.observers['item.**'].call(row,row.data.item);
  assert.equal(row.data.counts.views,'1.2M');
  row.data.item.likeCount=1000;
  def.observers['item.**'].call(row,row.data.item);
  assert.equal(row.data.counts.likes,'1K');
  row.toggleLike();
  row.openReply();
  row.showOptions();
  sheet.success({tapIndex:0});
  sheet.success({tapIndex:1});
  row.stopTap();
  assert.equal(JSON.stringify(events),JSON.stringify([{name:'like',detail:{index:3,listKey:'favoritePosts'}},{name:'open',detail:{id:'p1',focusReply:true}},{name:'favorite',detail:{index:3,listKey:'favoritePosts'}},{name:'open',detail:{id:'p1'}}]));
});

test('home reply opens post detail in reply mode and detail focuses its composer', () => {
  let target = '';
  const home = load('pages/treehole/index.js', {
    sharePost() {}, SORT_OPTIONS: [],
    wx: { navigateTo: ({ url }) => { target = url; } }
  });
  home.goToDetail({ detail: { id: 'p1', focusReply: true } });
  assert.equal(target, '/pages/campus/post-detail/index?id=p1&reply=1');
  assert.match(read('pages/campus/post-detail/index.wxml'), /focus="{{commentInputFocus}}"/);
});
test('sharing from every post list targets the selected post, menu sharing opens home', () => {
  const share=loadFunction('utils/share.js','sharePost');
  const result=share({from:'button',target:{dataset:{postId:'p 1&2',title:'校园帖子'}}});
  assert.equal(result.path,'/pages/campus/post-detail/index?id=p%201%262');
  assert.equal(result.title,'校园帖子');
  assert.equal(share({from:'menu'}).path,'/pages/treehole/index');
  const walk=d=>fs.readdirSync(d,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(d,e.name)):[path.join(d,e.name)]);
  for(const p of walk(path.join(root,'pages')).filter(p=>p.endsWith('.wxml'))) {
    if(fs.readFileSync(p,'utf8').includes('<post-row')) assert.match(fs.readFileSync(p.replace('.wxml','.js'),'utf8'),/onShareAppMessage:\s*sharePost/);
  }
});
test('custom navigation reserves measured WeChat capsule space on small and large screens', () => {
  for(const width of [320,390,430]) {
    const menu={top:48,height:32,left:width-94};
    const app=load('app.js',{wx:{getWindowInfo:()=>({windowWidth:width,statusBarHeight:40}),getMenuButtonBoundingClientRect:()=>menu}});
    app.initSystemInfo();
    assert.equal(app.globalData.navTop,48);
    assert.equal(app.globalData.navHeight,32);
    assert.equal(app.globalData.navRight,102);
    assert.ok(width-app.globalData.navRight < menu.left);
  }
});

test('drawer uses measured navigation insets instead of a fixed status bar offset', () => {
  let hidden = 0;
  let shown = 0;
  const def = load('components/radio-drawer/index.js', {
    getApp: () => ({ globalData: { navTop: 48, navHeight: 32 } }),
    getCurrentPages: () => [],
    wx: {
      hideTabBar: () => { hidden += 1; },
      showTabBar: () => { shown += 1; }
    }
  });
  const drawer = {
    ...def.methods,
    data: { ...def.data },
    setData(value) { Object.assign(this.data, value); }
  };
  def.lifetimes.attached.call(drawer);
  drawer.setTabBarVisibility(true);
  drawer.setTabBarVisibility(false);
  assert.equal(drawer.data.navTop, 48);
  assert.equal(drawer.data.navHeight, 32);
  assert.equal(hidden, 1);
  assert.equal(shown, 1);
  assert.match(read('components/radio-drawer/index.wxml'), /drawer-panel motion-sidebar" style="padding-top: {{navTop}}px;/);
  assert.match(read('components/radio-drawer/index.wxml'), /scroll-y enhanced/);
  assert.match(read('components/radio-drawer/index.wxml'), /drawer-scroll-end/);
  assert.match(read('components/radio-drawer/index.wxss'), /drawer-scroll-end[^}]*safe-area-inset-bottom/);
  assert.doesNotMatch(read('components/radio-drawer/index.wxml'), /<button class="drawer-close"/);
  assert.match(read('pages/treehole/index.wxml'), /show-scrollbar="{{false}}"/);
});

test('campus is a root tab and legacy search remains outside tab navigation', () => {
  const app = JSON.parse(read('app.json'));
  const tabs = app.tabBar.list.map(item => item.pagePath);
  assert.equal(tabs[1], 'pages/campus/index');
  assert.ok(!tabs.includes('pages/campus/search/index'));
  assert.match(read('custom-tab-bar/index.js'), /"pagePath":"pages\/campus\/index","text":"校园"/);
  assert.match(read('pages/campus/index.wxml'), /<social-header fixed back/);
  assert.doesNotMatch(read('components/radio-drawer/index.wxml'), /bindtap="goCampus"/);
  assert.doesNotMatch(read('pages/treehole/index.js'), /goSearch\(\)[\s\S]*wx\.navigateTo\(\{ url: '\/pages\/campus\/search\/index'/);
});

test('post views are deduplicated into browsing history and reopen the post', () => {
  let rows = [];
  const scope = {
    wx: {
      getStorageSync: () => rows,
      setStorageSync: (key, value) => { assert.equal(key, 'browseHistory'); rows = value; },
      removeStorageSync: () => { rows = []; }
    }
  };
  vm.runInNewContext(strip(read('utils/browse_history.js')) + ';this.api={recordPostView,getBrowseHistory,clearBrowseHistory};', scope);
  scope.api.recordPostView({ id: 'p1', title: '第一次', content: '正文', authorAlias: '同学甲' });
  scope.api.recordPostView({ id: 'p1', title: '第二次', content: '更新正文', authorAlias: '同学甲' });
  assert.equal(rows.length, 1);
  assert.equal(rows[0].title, '第二次');
  assert.match(read('pages/campus/post-detail/index.js'), /recordPostView\(displayPost\)/);
  assert.match(read('pages/ai/history/index.wxml'), /bindtap="openPost"/);
  assert.equal(JSON.parse(read('pages/ai/history/index.json')).navigationBarTitleText, '历史记录');
});

test('home publish action is a fixed X-style blue circle', () => {
  const css = read('pages/treehole/index.wxss');
  assert.match(css, /\.floating-publish \{[^}]*width: 56px;[^}]*min-width: 56px;[^}]*max-width: 56px;/);
  assert.match(css, /\.floating-publish \{[^}]*height: 56px;[^}]*min-height: 56px;/);
  assert.match(css, /\.floating-publish \{[^}]*margin: 0;[^}]*padding: 0;[^}]*border-radius: 50%;[^}]*background: var\(--app-accent\);/);
  assert.match(css, /\.floating-publish::after \{ border: 0; \}/);
});

test('primary destinations use fixed X-style shells instead of document-flow dashboards', () => {
  for (const file of [
    'pages/campus/search/index.wxml',
    'pages/profile/notifications/index.wxml',
    'pages/profile/conversations/index.wxml'
  ]) {
    assert.match(read(file), /<social-header fixed/);
    assert.match(read(file), /<scroll-view/);
    assert.match(read(file), /show-scrollbar="{{false}}"/);
  }
  assert.match(read('pages/campus/create-post/index.wxml'), /class="composer-shell"/);
  assert.match(read('pages/campus/create-post/index.wxss'), /\.content-input\s*\{[^}]*background:\s*transparent/);
  assert.doesNotMatch(read('pages/campus/create-post/index.wxml'), /class="content-highlight"/);
  assert.match(read('pages/campus/index.wxss'), /\.shortcut-grid \{ display:flex; flex-wrap:wrap/);
  assert.match(read('pages/campus/index.wxss'), /\.shortcut-slot \{[^}]*flex:0 0 25%/);
});

test('home college tab renders only colleges in a two-column selector', async () => {
  const home = load('pages/treehole/index.js', {
    sharePost() {},
    getSectionsTree: async () => ({
      data: {
        sections: [
          { id: 'general', sectionName: '校园生活', sectionType: 'public' },
          { id: 'cs', sectionName: '计算机科学与技术学院', sectionType: 'college' }
        ],
        colleges: [
          { id: 'cs', sectionName: '计算机科学与技术学院', sectionType: 'college' },
          { id: 'ee', sectionName: '电子工程学院', sectionType: 'college' }
        ]
      }
    })
  });
  const page = {
    ...home,
    data: JSON.parse(JSON.stringify(home.data)),
    setData: require('./support/set-data.cjs')
  };
  assert.deepEqual(Array.from(page.data.homeTabs, item => item.label), ['推荐', '学院', '最新', '社团', '组织']);
  await page.loadCollegeOptions();
  assert.deepEqual(Array.from(page.data.collegeOptions, item => item.sectionName), ['计算机科学与技术学院', '电子工程学院']);
  page.onHomeTabTap({ currentTarget: { dataset: { tab: 'colleges' } } });
  page.selectCollege({ currentTarget: { dataset: { college: page.data.collegeOptions[1] } } });
  assert.equal(page.getFeed().activeCollege.sectionName, '电子工程学院');
  assert.equal(page.data.activeHomeTab, 'colleges');
  assert.match(read('pages/treehole/index.wxml'), /wx:for="{{homeTabs}}"/);
  assert.match(read('pages/treehole/index.wxss'), /\.college-grid \{[^}]*grid-template-columns: repeat\(2,/);
  assert.doesNotMatch(read('pages/campus/search/index.wxml'), /category-trigger|category-browser/);
});

test('home search stays outside the five-tab scrollable index at the far right', () => {
  const wxml = read('pages/treehole/index.wxml');
  const css = read('pages/treehole/index.wxss');
  const search = read('pages/campus/search/index.wxml');
  assert.match(wxml, /<view class="feed-tab-viewport">\s*<scroll-view class="feed-tab-scroll" scroll-x enhanced show-scrollbar="{{false}}"[^>]*>[\s\S]*class="feed-tab-list">[\s\S]*wx:for="{{homeTabs}}"[\s\S]*<\/scroll-view>\s*<\/view>\s*<view class="feed-search-area">\s*<view class="feed-tab-fade" aria-hidden="true"><\/view>\s*<button class="feed-search" bindtap="goSearch"/);
  assert.match(css, /\.feed-tab-viewport\s*\{[^}]*flex:1;[^}]*min-width:0;[^}]*overflow:hidden;/);
  assert.match(css, /\.feed-tab-scroll\s*\{[^}]*width:100%;[^}]*white-space:nowrap;/);
  assert.match(css, /\.feed-tab-list\s*\{[^}]*display:inline-flex;[^}]*min-width:100%;/);
  assert.match(css, /\.feed-tab\s*\{[^}]*flex:0 0 88px;[^}]*width:88px;/);
  assert.match(css, /\.feed-tabs\s*\{[^}]*width:100vw;/);
  assert.match(css, /\.feed-search\s*\{[^}]*flex:0 0 44px;[^}]*width:44px;[^}]*margin:0 0 0 auto;/);
  assert.match(css, /\.feed-search \.ui-icon\s*\{[^}]*width:20px;[^}]*height:20px;/);
  assert.match(search, /<social-header fixed back brand="{{false}}">/);
});

test('home index fades at the fixed search edge without intercepting touch or leaking into search mode', () => {
  const css = read('pages/treehole/index.wxss');
  assert.doesNotMatch(css, /\.feed-tab-viewport::after/);
  assert.match(css, /\.feed-search-area \{[^}]*z-index:2;[^}]*flex:0 0 44px;[^}]*overflow:visible;[^}]*background:var\(--app-surface\)/);
  assert.match(css, /\.feed-tab-fade\s*\{[^}]*position:absolute;[^}]*bottom:0;[^}]*left:-28px;[^}]*width:32px;[^}]*linear-gradient\(to right, transparent, var\(--app-surface\) 22px, var\(--app-surface\)\);[^}]*pointer-events:none;/);
  assert.match(css, /\.feed-tabs \{[^}]*background:var\(--app-surface\)/);
  assert.match(css, /\.feed-tabs\.searching \.feed-tab-viewport, \.feed-tabs\.searching \.feed-search-area[^}]*visibility:hidden/);
});

test('home search expands over the index and returns results without page navigation', async () => {
  let requested;
  const home = load('pages/treehole/index.js', {
    sharePost() {},
    getPosts: async (params) => {
      requested = params;
      return [{ id: 'p-search', title: '图书馆插座' }];
    },
    attachDisplayImages: post => post,
    hydrateDisplayImages: async () => ({}),
    applyHydratedDisplayImages: posts => posts,
    wx: { showToast() {} }
  });
  const page = {
    ...home,
    data: { ...home.data },
    setData(value) { Object.assign(this.data, value); }
  };
  page.goSearch();
  assert.equal(page.data.searchOpen, true);
  page.data.headerCollapsed = false;
  page._lastScrollTop = 0;
  page._scrollDownDistance = 0;
  page._scrollUpDistance = 0;
  page.onScroll({ currentTarget: { dataset: { tab: 'search' } }, detail: { scrollTop: 30 } });
  assert.equal(page.data.headerCollapsed, true);
  page.onScroll({ currentTarget: { dataset: { tab: 'search' } }, detail: { scrollTop: 10 } });
  assert.equal(page.data.headerCollapsed, false);
  page.onInlineSearchInput({ detail: { value: '图书馆' } });
  await page.submitInlineSearch();
  assert.equal(requested.keyword, '图书馆');
  assert.equal(page.data.searchResults[0].id, 'p-search');
  page.closeInlineSearch();
  assert.equal(page.data.searchOpen, false);
  assert.equal(page.data.searchResults.length, 0);
  const wxml = read('pages/treehole/index.wxml');
  assert.match(wxml, /wx:if="{{searchOpen}}"[\s\S]*class="inline-search-bar"/);
  assert.match(wxml, /bindconfirm="submitInlineSearch"/);
  assert.match(wxml, /class="inline-search-exit" bindtap="closeInlineSearch"/);
  assert.match(wxml, /class="inline-search-submit" bindtap="submitInlineSearch">搜索<\/button>/);
  assert.match(wxml, /wx:for="{{searchResults}}"/);
  const css = read('pages/treehole/index.wxss');
  assert.match(css, /\.feed-tabs\.searching \.feed-tab-viewport, \.feed-tabs\.searching \.feed-search-area[^}]*visibility:hidden/);
  assert.match(css, /@keyframes inline-search-in/);
});

test('post adapter preserves backend pagination metadata', async () => {
  let requested;
  const scope = {
    request: {
      get: async (url, params) => {
        requested = { url, params };
        return { data: { items: [{ id: 'p1' }], page: 2, limit: 10, total: 21, hasMore: true } };
      }
    },
    getData: response => response.data,
    normalizePost: post => ({ ...post, normalized: true }),
    normalizeComment: value => value,
    responseContractError: message => new Error(message),
    toArray: value => value
  };
  vm.runInNewContext(strip(read('api/posts.js')) + ';this.getPostsPageResult=getPostsPage;', scope);
  const result = await scope.getPostsPageResult({ page: 2, limit: 10, sort: 'latest' });
  assert.equal(requested.url, '/api/posts');
  assert.equal(requested.params.page, 2);
  assert.equal(requested.params.limit, 10);
  assert.equal(result.items[0].normalized, true);
  assert.equal(result.total, 21);
  assert.equal(result.hasMore, true);
});

test('home feed appends finite pages, deduplicates rows, and refreshes page one', async () => {
  const calls = [];
  const responses = [
    { items: [{ id: 'p1' }, { id: 'p2' }], page: 1, limit: 2, total: 3, hasMore: true },
    { items: [{ id: 'p2' }, { id: 'p3' }], page: 2, limit: 2, total: 3, hasMore: false },
    { items: [{ id: 'p4' }], page: 1, limit: 2, total: 1, hasMore: false }
  ];
  const home = load('pages/treehole/index.js', {
    sharePost() {},
    getPostsPage: async params => {
      calls.push(params);
      return responses[calls.length - 1];
    },
    attachDisplayImages: post => post,
    hydrateDisplayImages: async () => ({}),
    applyHydratedDisplayImages: posts => posts,
    setTimeout: callback => callback(),
    wx: { stopPullDownRefresh() {} }
  });
  const page = {
    ...home,
    data: JSON.parse(JSON.stringify(home.data)),
    setData: require('./support/set-data.cjs')
  };
  page.setFeedState('hot', { limit: 2 });
  await page.fetchPosts();
  assert.deepEqual(Array.from(page.getFeed().posts, post => post.id), ['p1', 'p2']);
  assert.equal(page.getFeed().page, 2);
  assert.equal(page.getFeed().hasMore, true);
  await page.onReachBottom();
  assert.deepEqual(Array.from(page.getFeed().posts, post => post.id), ['p1', 'p2', 'p3']);
  assert.equal(page.getFeed().totalPosts, 3);
  assert.equal(page.getFeed().hasMore, false);
  await page.onReachBottom();
  assert.equal(calls.length, 2);
  await page.refreshFeed();
  assert.deepEqual(Array.from(page.getFeed().posts, post => post.id), ['p4']);
  assert.equal(page.getFeed().page, 2);
  assert.equal(page.getFeed().totalPosts, 1);
  const wxml = read('pages/treehole/index.wxml');
  assert.match(wxml, /lower-threshold="160"/);
  assert.match(wxml, /bindrefresherrefresh="onRefresherRefresh"/);
  assert.match(wxml, /bindscrolltolower="onReachBottom"/);
});

test('home chrome collapses on downward reading and restores on upward scrolling', () => {
  const home = load('pages/treehole/index.js', { sharePost() {} });
  const page = {
    ...home,
    data: JSON.parse(JSON.stringify(home.data)),
    setData: require('./support/set-data.cjs')
  };
  page.onScroll({ currentTarget: { dataset: { tab: 'hot' } }, detail: { scrollTop: 0 } });
  page.onScroll({ currentTarget: { dataset: { tab: 'hot' } }, detail: { scrollTop: 30 } });
  assert.equal(page.data.headerCollapsed, true);
  assert.equal(page.data.showPublishButton, false);
  page.onScroll({ currentTarget: { dataset: { tab: 'hot' } }, detail: { scrollTop: 10 } });
  assert.equal(page.data.headerCollapsed, false);
  assert.equal(page.data.showPublishButton, true);
  page.onScroll({ currentTarget: { dataset: { tab: 'hot' } }, detail: { scrollTop: 900 } });
  assert.equal(page.data.showBackToTop, true);
  page.backToTop();
  assert.equal(page.getFeed().feedScrollIntoView, 'feed-top-hot');
  assert.equal(page.data.showBackToTop, false);
  assert.equal(page.data.headerCollapsed, false);
  const wxml = read('pages/treehole/index.wxml');
  assert.match(wxml, /<social-header fixed collapsed="{{headerCollapsed}}"/);
  assert.match(wxml, /class="feed-tabs {{searchOpen \? 'searching' : ''}}" style="top: {{headerCollapsed \? navTop : navTop \+ navHeight \+ 8}}px; padding-right: {{headerCollapsed && !searchOpen \? navRight : 0}}px;"/);
  assert.match(wxml, /scroll-into-view="{{feed.feedScrollIntoView}}"/);
  assert.match(wxml, /class="back-to-top" bindtap="backToTop"/);
  assert.match(read('pages/treehole/index.wxss'), /\.back-to-top \{[^}]*width:44px;[^}]*height:44px;/);
  assert.match(read('components/social-header/index.wxss'), /\.fixed\.collapsed[^}]*translateY\(-100%\)/);
});

test('notification and message tabs filter existing client data without changing API calls', () => {
  const notifications = load('pages/profile/notifications/index.js');
  const noticePage = {
    ...notifications,
    data: { items: [], displayedItems: [], activeFilter: 'all' },
    setData(value) { Object.assign(this.data, value); }
  };
  const notices = [
    { id: 'n1', type: 'comment', title: '有人回复了你' },
    { id: 'n2', type: 'like', title: '有人点赞了你的评论', relatedType: 'comment' }
  ];
  assert.equal(noticePage.applyFilter(notices, 'replies').length, 1);

  const conversations = load('pages/profile/conversations/index.js');
  const messagePage = { ...conversations, data: { conversations: [], searchKeyword: '' } };
  const visible = messagePage.applyConversationFilter([
    { id: 'c1', name: '图书馆同学', lastMessage: '下午见' },
    { id: 'c2', name: '实验室同学', lastMessage: '报告发你了' }
  ], '报告');
  assert.equal(visible.length, 1);
  assert.equal(visible[0].sourceIndex, 1);
  assert.doesNotMatch(read('pages/profile/conversations/index.wxml'), /icon-compose/);
});

test('primary navigation and content surfaces have lightweight motion feedback', () => {
  assert.match(read('app.wxss'), /@import "\.\/styles\/motion.wxss"/);
  assert.match(read('styles/motion.wxss'), /motion-enter-a[^{]*\{ animation: page-reveal-a/);
  assert.match(read('app.wxss'), /prefers-reduced-motion/);
  assert.match(read('custom-tab-bar/index.js'), /setTimeout\([\s\S]*wx\.switchTab/);
  assert.match(read('custom-tab-bar/index.wxss'), /tab-select/);
  assert.match(read('components/radio-drawer/index.wxss'), /drawer-panel-in/);
  assert.match(read('components/post-row/index.wxss'), /post-row-enter/);
  assert.match(read('styles/section-tabs.wxss'), /transition:transform \.42s/);
  assert.match(read('pages/profile/notifications/index.wxml'), /notification-body motion-content/);
});

test('profile dark mode separates its header, chrome, content and overlay layers', () => {
  const css = read('pages/profile/index.wxss');
  assert.match(css, /\.profile-page[^}]*background: var\(--app-background\)/);
  assert.match(css, /\.profile-header[^}]*background:var\(--app-surface\)/);
  assert.match(css, /\.profile-background[^}]*background: var\(--app-card\)/);
  assert.match(css, /\.profile-tab-body[^}]*background:var\(--app-background\)/);
  assert.match(css, /\.follow-sheet-mask[\s\S]*background: var\(--app-scrim\)/);
  assert.match(css, /\.follow-sheet[\s\S]*background: var\(--app-card\)/);
});

test('AI uses one in-tab workspace with a collapsible conversation sidebar', () => {
  const js = read('pages/ai/index.js');
  const wxml = read('pages/ai/index.wxml');
  assert.doesNotMatch(js, /navigateTo\([\s\S]*pages\/ai\/chat\/index/);
  assert.match(js, /sendAiMessage\(text/);
  assert.match(js, /CONVERSATIONS_KEY = 'aiConversations'/);
  assert.match(wxml, /class="ai-sidebar(?:\s[^"]*)?"/);
  assert.match(wxml, /bindtap="selectConversation"/);
  assert.match(wxml, /class="ai-chat-scroll"/);
  assert.match(wxml, /bindtap="submitQuestion"/);
  assert.match(read('utils/ai_workspace.js'), /wx\.switchTab\(\{ url: '\/pages\/ai\/index' \}\)/);
});

test('AI conversation rows expose ChatGPT-style long-press rename and delete actions', () => {
  const wxml = read('pages/ai/index.wxml');
  const js = read('pages/ai/index.js');
  const css = read('pages/ai/index.wxss');
  assert.match(wxml, /catchlongpress="openConversationMenu"/);
  assert.match(wxml, /bindtap="beginRenameConversation"/);
  assert.match(wxml, /bindtap="beginDeleteConversation"/);
  assert.match(wxml, /bindtap="confirmDeleteConversation"/);
  assert.doesNotMatch(wxml, /ai-conversation-delete/);
  assert.match(js, /saveConversationName\(\)[\s\S]*wx\.setStorageSync\(CONVERSATIONS_KEY/);
  assert.match(js, /confirmDeleteConversation\(\)[\s\S]*wx\.removeStorageSync\(ACTIVE_CONVERSATION_KEY/);
  assert.match(css, /\.ai-conversation-menu-mask\s*\{[^}]*rgba\(3,\s*6,\s*10,\s*\.72\)/);
});
