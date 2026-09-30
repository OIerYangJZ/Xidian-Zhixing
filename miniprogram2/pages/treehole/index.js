import { enterPage } from '../../utils/motion';
import { sharePost } from '../../utils/share';
import { getUserInfo } from '../../api/auth';
import { getPosts, getPostsPage } from '../../api/posts';
import { getSectionsTree } from '../../api/campus';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';
import { avatarInitial } from '../../utils/format';
import { applyHydratedDisplayImages, attachDisplayImages, hydrateDisplayImages } from '../../utils/feed_images';
import { togglePostFavoriteInList, togglePostLikeInList } from '../../utils/post_actions';

const HOME_TABS = [
  { label: '推荐', value: 'hot' },
  { label: '学院', value: 'colleges' },
  { label: '最新', value: 'latest' },
  { label: '社团', value: 'clubs' },
  { label: '组织', value: 'organizations' }
].map(tab => ({
  ...tab,
  posts: [], loading: false, initialized: false, hasMore: tab.value === 'hot' || tab.value === 'latest',
  page: 1, limit: 10, totalPosts: 0, activeCollege: null,
  errorMessage: '', refreshTriggered: false, refreshFeedbackVisible: false,
  feedScrollIntoView: ''
}));

const buildCollegeOptions = (tree = {}) => {
  const colleges = [];
  [...(tree.colleges || []), ...(tree.sections || [])].forEach((section) => {
    if (!section || (section.sectionType && section.sectionType !== 'college')) return;
    const id = section.sectionId || section.id;
    const sectionName = section.sectionName || section.name;
    if (!id || !sectionName) return;
    if (colleges.some((item) => item.id === id || item.sectionName === sectionName)) return;
    colleges.push({ ...section, id, sectionName, sectionType: 'college' });
  });
  return colleges;
};

Page({
  onShareAppMessage: sharePost,
  data: {
    homeTabs: HOME_TABS,
    activeHomeTab: 'hot',
    activeHomeTabIndex: 0,
    collegeOptions: [],
    showPublishButton: true,
    showBackToTop: false,
    drawerOpen: false,
    navTop: 0,
    navHeight: 48,
    navRight: 100,
    headerCollapsed: false,
    searchOpen: false,
    searchKeyword: '',
    searchResults: [],
    searchLoading: false,
    searchSearched: false,
    searchError: '',
    userInfo: null,
    bootstrapError: ''
  },

  onLoad() {
    this._pageUnloaded = false;
    this.initCustomNav();
  },

  onShow() {
    enterPage(this, { animate: false });
    applyThemeAndLanguage(this);
    this.initCustomNav();
    if (!this._homeInitialized && !this.data.bootstrapError) return this.initializeHome();
  },

  async initializeHome() {
    if (this._pageUnloaded || this._initializingHome || !requireLoginPage()) return;
    this._initializingHome = true;
    this.setData({ bootstrapError: '' });
    try {
      await Promise.all([this.loadUserInfo(), this.loadCollegeOptions()]);
      if (this._pageUnloaded) return;
      this._homeInitialized = true;
      if (!this.getFeed().initialized) await this.fetchPosts();
    } catch (error) {
      if (this._pageUnloaded) return;
      this.setData({
        bootstrapError: (error && error.data && error.data.message)
          || (error && error.message) || '页面初始化失败，请重试'
      });
    } finally {
      this._initializingHome = false;
    }
  },

  onHide() {
    this._homePagerTouch = false;
    this._pendingHomeSwipe = null;
    this._touchStart = null;
    this._homeTabVisibilityRequest = (this._homeTabVisibilityRequest || 0) + 1;
  },

  onUnload() {
    this._pageUnloaded = true;
    this._pendingHomeSwipe = null;
    this._homeTabVisibilityRequest = (this._homeTabVisibilityRequest || 0) + 1;
    this._searchRequestId = (this._searchRequestId || 0) + 1;
  },

  onPullDownRefresh() {
    this.refreshFeed({ stopPageRefresh: true });
  },

  initCustomNav() {
    const app = getApp();
    if (wx.getWindowInfo) {
      const windowInfo = wx.getWindowInfo();
      this._backToTopThreshold = Math.max(640, Math.round((windowInfo.windowHeight || 0) * 1.15));
    }
    this.setData({
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32,
      navRight: app.globalData.navRight || 100
    });
  },

  async loadUserInfo() {
    const response = await getUserInfo();
    if (this._pageUnloaded) return;
    const user = response.data;
    this.setData({
      userInfo: {
        ...user,
        avatarInitial: avatarInitial(user.nickname || user.alias)
      }
    });
  },

  async loadCollegeOptions() {
    try {
      const response = await getSectionsTree();
      if (this._pageUnloaded) return;
      const tree = response.data || response || {};
      this.setData({ collegeOptions: buildCollegeOptions(tree) });
    } catch (error) {
      // Keep the main feed usable if college metadata is temporarily unavailable.
    }
  },

  onHomeTabTap(event) {
    this._pendingHomeSwipe = null;
    this.switchHomeTab(HOME_TABS.findIndex(item => item.value === event.currentTarget.dataset.tab));
  },

  switchHomeTab(index) {
    if (this.data.searchOpen || this.data.drawerOpen || !Number.isInteger(index) || !HOME_TABS[index] || index === this.data.activeHomeTabIndex) return;
    const tab = HOME_TABS[index].value;
    this._lastScrollTop = (this._feedScrollTops && this._feedScrollTops[tab]) || 0;
    this._scrollDownDistance = 0;
    this._scrollUpDistance = 0;
    this.setData({
      activeHomeTab: tab,
      activeHomeTabIndex: index,
      showPublishButton: this.isPostFeed(tab),
      showBackToTop: this.isPostFeed(tab) && this._lastScrollTop > (this._backToTopThreshold || 800)
    }, () => {
      this.ensureHomeTabVisible(tab);
      const feed = this.getFeed(tab);
      if (this.isPostFeed(tab) && !feed.initialized && !feed.loading) this.fetchPosts({ tab });
    });
  },

  onHomeSwipeChange(event) {
    if (event.target.id !== 'home-pager' || event.detail.source !== 'touch' || this.data.searchOpen || this.data.drawerOpen || this._pageUnloaded) return;
    const index = Number(event.detail.current);
    if (!Number.isInteger(index) || !HOME_TABS[index]) return;
    // Do not write the bound current or load the next feed while native swipe settling is in progress.
    this._pendingHomeSwipe = index;
  },

  onHomeSwipeFinish(event) {
    if (event.target.id !== 'home-pager' || this.data.searchOpen || this.data.drawerOpen || this._pageUnloaded || this._homePagerTouch) return;
    const index = Number(event.detail.current);
    if (event.detail.source === 'touch') {
      if (index !== this._pendingHomeSwipe) return;
      this._pendingHomeSwipe = null;
      this.switchHomeTab(index);
    }
    if (index !== this.data.activeHomeTabIndex) return;
    if (!this._lastScrollTop && this.data.headerCollapsed) this.setData({ headerCollapsed: false });
  },

  onHomePagerTouchStart() {
    this._homePagerTouch = true;
    this._touchStart = null;
  },

  onHomePagerTouchEnd() {
    this._homePagerTouch = false;
  },

  getFeed(tab = this.data.activeHomeTab) {
    return this.data.homeTabs.find(item => item.value === tab);
  },

  setFeedState(tab, updates, callback) {
    if (this._pageUnloaded) return;
    const index = this.data.homeTabs.findIndex(item => item.value === tab);
    const patch = {};
    Object.keys(updates).forEach(key => { patch[`homeTabs[${index}].${key}`] = updates[key]; });
    this.setData(patch, callback);
  },

  ensureHomeTabVisible(tab) {
    const request = this._homeTabVisibilityRequest = (this._homeTabVisibilityRequest || 0) + 1;
    const query = wx.createSelectorQuery().in(this);
    query.select('.feed-tab-scroll').fields({ node: true, rect: true, scrollOffset: true });
    query.select(`#home-tab-${tab}`).boundingClientRect();
    query.exec(([viewport, item]) => {
      if (request !== this._homeTabVisibilityRequest || this.data.activeHomeTab !== tab || this.data.searchOpen || !viewport || !item) return;
      const delta = item.left < viewport.left ? item.left - viewport.left
        : item.right > viewport.right ? item.right - viewport.right : 0;
      if (Math.abs(delta) < 1) return;
      viewport.node.scrollTo({ left: Math.max(0, viewport.scrollLeft + delta), animated: true, duration: 360 });
    });
  },

  isPlaceholderTab(tab = this.data.activeHomeTab) {
    return tab === 'clubs' || tab === 'organizations';
  },

  isPostFeed(tab = this.data.activeHomeTab) {
    return tab === 'hot' || tab === 'latest'
      || (tab === 'colleges' && Boolean(this.getFeed(tab).activeCollege));
  },

  selectCollege(event) {
    const college = event.currentTarget.dataset.college;
    if (!college || this.data.activeHomeTab !== 'colleges') return;
    this.invalidateFeedRequests('colleges');
    this.setFeedState('colleges', {
      activeCollege: college,
      posts: [],
      page: 1,
      totalPosts: 0,
      hasMore: true,
      initialized: false,
      loading: false,
      refreshTriggered: false,
      refreshFeedbackVisible: false,
      errorMessage: ''
    }, () => this.fetchPosts({ tab: 'colleges', page: 1, replace: true, force: true }));
  },

  clearActiveCollege() {
    this._feedScrollTops = { ...this._feedScrollTops, colleges: 0 };
    this.invalidateFeedRequests('colleges');
    this.setFeedState('colleges', {
      activeCollege: null,
      posts: [],
      page: 1,
      totalPosts: 0,
      hasMore: false,
      initialized: false,
      loading: false,
      refreshTriggered: false,
      refreshFeedbackVisible: false,
      errorMessage: ''
    });
  },

  async refreshFeed(options = {}) {
    const tab = options.tab || this.data.activeHomeTab;
    if (this.isPlaceholderTab(tab)) {
      if (options.stopPageRefresh) wx.stopPullDownRefresh();
      return;
    }
    if (tab === 'colleges' && !this.getFeed(tab).activeCollege) {
      this.setFeedState(tab, { refreshTriggered: true });
      await this.loadCollegeOptions().finally(() => {
        this.setFeedState(tab, { refreshTriggered: false });
        if (options.stopPageRefresh) wx.stopPullDownRefresh();
      });
      return;
    }
    this.setFeedState(tab, {
      refreshTriggered: true,
      refreshFeedbackVisible: true,
      errorMessage: ''
    });
    const pending = this.fetchPosts({ tab, page: 1, replace: true, force: true });
    const request = this._feedRequests[tab];
    try {
      await pending;
    } finally {
      if (options.stopPageRefresh) wx.stopPullDownRefresh();
      if (request === this._feedRequests[tab]) this.setFeedState(tab, { refreshTriggered: false, refreshFeedbackVisible: false });
    }
  },

  onRefresherRefresh(event) {
    const tab = event.currentTarget.dataset.tab;
    if (tab === this.data.activeHomeTab && !this.data.searchOpen) return this.refreshFeed({ tab });
  },

  invalidateFeedRequests(tab = this.data.activeHomeTab) {
    if (!this._feedRequests) this._feedRequests = {};
    this._feedRequests[tab] = (this._feedRequests[tab] || 0) + 1;
    return this._feedRequests[tab];
  },

  async fetchPosts(options = {}) {
    const tab = options.tab || this.data.activeHomeTab;
    if (this._pageUnloaded || !this.isPostFeed(tab)) return;
    const feed = this.getFeed(tab);
    const replace = Boolean(options.replace);
    const force = Boolean(options.force);
    if (!force && (feed.loading || !feed.hasMore)) return;
    const requestedPage = Number(options.page) || feed.page;
    const requestId = this.invalidateFeedRequests(tab);
    const params = {
      page: requestedPage,
      limit: feed.limit,
      sort: tab === 'hot' ? 'hot' : 'latest'
    };
    if (feed.activeCollege) {
      params.sectionId = feed.activeCollege.sectionId || feed.activeCollege.id;
      params.sectionType = 'college';
    }
    this.setFeedState(tab, { loading: true, initialized: true, errorMessage: '' });
    try {
      const result = await getPostsPage(params);
      if (this._pageUnloaded || requestId !== this._feedRequests[tab]) return;
      const currentUserId = String((this.data.userInfo && this.data.userInfo.id) || '').trim();
      const newPosts = result.items.map((post) => {
        const authorUserId = String(post.authorUserId || post.authorId || '').trim();
        const isFollowingAuthor = Boolean(post.followingAuthor || post.isFollowingAuthor || post.isFollowing);
        return attachDisplayImages({
          ...post,
          canShowFollowDot: Boolean(authorUserId && !post.isAnonymous && authorUserId !== currentUserId && !isFollowingAuthor)
        });
      });
      const existingPosts = replace || requestedPage === 1 ? [] : this.getFeed(tab).posts;
      const knownIds = new Set(existingPosts.map((post) => post.id));
      const posts = existingPosts.concat(newPosts.filter((post) => !knownIds.has(post.id)));
      this.setFeedState(tab, {
        posts,
        page: result.page + 1,
        totalPosts: result.total,
        hasMore: result.hasMore,
        loading: false
      });
      await this.hydrateFeedImages(tab, requestId);
    } catch (error) {
      if (this._pageUnloaded || requestId !== this._feedRequests[tab]) return;
      this.setFeedState(tab, {
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '帖子加载失败，请重试'
      });
    }
  },

  async hydrateFeedImages(tab, requestId) {
    const posts = this.getFeed(tab).posts;
    const hydratedByPostId = await hydrateDisplayImages(posts);
    if (this._pageUnloaded || requestId !== this._feedRequests[tab]) return;
    const hydratedPosts = applyHydratedDisplayImages(this.getFeed(tab).posts, hydratedByPostId);
    if (hydratedPosts !== this.getFeed(tab).posts) {
      this.setFeedState(tab, { posts: hydratedPosts });
    }
  },

  onReachBottom(event) {
    if (this.data.searchOpen) return;
    if (event && event.currentTarget.dataset.tab !== this.data.activeHomeTab) return;
    return this.fetchPosts();
  },

  retryFeed(event) {
    return this.fetchPosts({ tab: event && event.currentTarget.dataset.tab, page: 1, replace: true, force: true });
  },

  retryLoadMore(event) {
    return this.fetchPosts({ tab: event && event.currentTarget.dataset.tab });
  },

  onScroll(event) {
    const scrollTop = event.detail.scrollTop;
    const tab = event.currentTarget.dataset.tab;
    if (!this._feedScrollTops) this._feedScrollTops = {};
    if (tab !== 'search') this._feedScrollTops[tab] = scrollTop;
    if ((tab === 'search' && !this.data.searchOpen) || (tab !== 'search' && (tab !== this.data.activeHomeTab || this.data.searchOpen))) return;
    if (this._lastScrollTop == null) this._lastScrollTop = scrollTop;
    const delta = scrollTop - this._lastScrollTop;
    if (delta > 0) {
      this._scrollDownDistance = (this._scrollDownDistance || 0) + delta;
      this._scrollUpDistance = 0;
    } else if (delta < 0) {
      this._scrollUpDistance = (this._scrollUpDistance || 0) - delta;
      this._scrollDownDistance = 0;
    }
    const updates = {};
    const canShowPublish = this.isPostFeed();
    const shouldShowBackToTop = this.isPostFeed() && !this.data.searchOpen
      && scrollTop > (this._backToTopThreshold || 800);
    if (shouldShowBackToTop !== this.data.showBackToTop) {
      updates.showBackToTop = shouldShowBackToTop;
    }
    if (scrollTop <= 4) {
      updates.headerCollapsed = false;
      updates.showBackToTop = false;
      if (tab !== 'search' && this.getFeed(tab).feedScrollIntoView) this.setFeedState(tab, { feedScrollIntoView: '' });
      if (canShowPublish) updates.showPublishButton = true;
    } else if (this._scrollDownDistance > 24) {
      updates.headerCollapsed = true;
      updates.showPublishButton = false;
      this._scrollDownDistance = 0;
    } else if (this._scrollUpDistance > 18) {
      updates.headerCollapsed = false;
      if (canShowPublish) updates.showPublishButton = true;
      this._scrollUpDistance = 0;
    }
    if (Object.keys(updates).length) this.setData(updates);
    this._lastScrollTop = scrollTop;
  },

  backToTop() {
    this._lastScrollTop = 0;
    this._scrollDownDistance = 0;
    this._scrollUpDistance = 0;
    const showPublishButton = this.isPostFeed();
    const tab = this.data.activeHomeTab;
    this._feedScrollTops = { ...this._feedScrollTops, [tab]: 0 };
    this.setFeedState(tab, { feedScrollIntoView: '' }, () => {
      this.setFeedState(tab, { feedScrollIntoView: `feed-top-${tab}` });
      this.setData({
        showBackToTop: false,
        headerCollapsed: false,
        showPublishButton
      });
    });
  },

  goToDetail(event) {
    const replyQuery = event.detail.focusReply ? '&reply=1' : '';
    wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${event.detail.id}${replyQuery}` });
  },

  goTagPosts(event) {
    const tag = event.detail.tag;
    if (!tag) return;
    wx.navigateTo({ url: `/pages/campus/tag-posts/index?tag=${encodeURIComponent(tag)}` });
  },

  async togglePostLike(event) {
    return this.toggleFeedPostAction(event, 'like');
  },

  async togglePostFavorite(event) {
    return this.toggleFeedPostAction(event, 'favorite');
  },

  async toggleFeedPostAction(event, action) {
    const tab = event.detail.listKey;
    const index = Number(event.detail.index);
    const posts = this.getFeed(tab).posts;
    const toggle = action === 'like' ? togglePostLikeInList : togglePostFavoriteInList;
    const result = await toggle(posts, index);
    if (this._pageUnloaded || !result[index]) return;
    const changed = result[index];
    const fields = action === 'like'
      ? { liked: changed.liked, isLiked: changed.isLiked, likeCount: changed.likeCount }
      : { favorited: changed.favorited, isFavorited: changed.isFavorited, favoriteCount: changed.favoriteCount };
    this.data.homeTabs.forEach(feed => {
      if (feed.posts.some(post => post.id === changed.id)) {
        this.setFeedState(feed.value, { posts: feed.posts.map(post => post.id === changed.id ? { ...post, ...fields } : post) });
      }
    });
  },

  openAuthorProfile(event) {
    const userId = event.detail.userId || '';
    const isAnonymous = String(event.detail.anonymous || '0') === '1';
    if (!userId || isAnonymous) return;
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${userId}` });
  },

  goSearch() {
    this.setData({
      searchOpen: true,
      showBackToTop: false,
      searchKeyword: '',
      searchResults: [],
      searchLoading: false,
      searchSearched: false,
      searchError: ''
    });
  },

  onInlineSearchInput(event) {
    this.setData({ searchKeyword: event.detail.value, searchError: '' });
  },

  closeInlineSearch() {
    this._searchRequestId = (this._searchRequestId || 0) + 1;
    this._lastScrollTop = (this._feedScrollTops && this._feedScrollTops[this.data.activeHomeTab]) || 0;
    this._scrollDownDistance = 0;
    this._scrollUpDistance = 0;
    this.setData({
      searchOpen: false,
      searchKeyword: '',
      searchResults: [],
      searchLoading: false,
      searchSearched: false,
      searchError: '',
      showBackToTop: this.isPostFeed() && this._lastScrollTop > (this._backToTopThreshold || 800)
    });
  },

  async submitInlineSearch() {
    const keyword = this.data.searchKeyword.trim();
    if (!keyword) {
      wx.showToast({ title: '请输入关键词', icon: 'none' });
      return;
    }
    const requestId = (this._searchRequestId || 0) + 1;
    this._searchRequestId = requestId;
    this._lastScrollTop = 0;
    this._scrollDownDistance = 0;
    this._scrollUpDistance = 0;
    this.setData({ searchLoading: true, searchSearched: true, searchError: '', searchResults: [] });
    try {
      const rows = await getPosts({ keyword, sort: 'latest', page: 1, limit: 30 });
      if (requestId !== this._searchRequestId) return;
      const searchResults = rows.map(attachDisplayImages);
      this.setData({ searchResults, searchLoading: false });
      const hydratedByPostId = await hydrateDisplayImages(searchResults);
      if (requestId !== this._searchRequestId) return;
      this.setData({ searchResults: applyHydratedDisplayImages(this.data.searchResults, hydratedByPostId) });
    } catch (error) {
      if (requestId !== this._searchRequestId) return;
      this.setData({ searchLoading: false, searchError: '搜索失败，请重试' });
    }
  },

  async toggleSearchPostLike(event) {
    const searchResults = await togglePostLikeInList(this.data.searchResults, Number(event.detail.index));
    this.setData({ searchResults });
  },

  async toggleSearchPostFavorite(event) {
    const searchResults = await togglePostFavoriteInList(this.data.searchResults, Number(event.detail.index));
    this.setData({ searchResults });
  },

  goCreatePost() {
    wx.navigateTo({ url: '/pages/campus/create-post/index' });
  },

  goClubApply() {
    wx.navigateTo({ url: '/pages/clubs/apply/index' });
  },

  goClubDetail(event) {
    wx.navigateTo({ url: `/pages/clubs/detail/index?id=${event.currentTarget.dataset.id}` });
  },

  openDrawer() {
    this.setData({ drawerOpen: true });
  },

  closeDrawer() {
    this.setData({ drawerOpen: false });
  },

  onTouchStart(event) {
    if (this.data.drawerOpen || this.data.searchOpen || this._homePagerTouch) {
      this._touchStart = null;
      return;
    }
    const touch = event.touches && event.touches[0];
    if (!touch) return;
    this._touchStart = { x: touch.clientX, y: touch.clientY };
  },

  onTouchEnd(event) {
    const touch = event.changedTouches && event.changedTouches[0];
    const start = this._touchStart;
    this._touchStart = null;
    if (this.data.drawerOpen || !touch || !start) return;
    const deltaX = touch.clientX - start.x;
    const deltaY = Math.abs(touch.clientY - start.y);
    if (start.x < 24 && deltaX > 70 && deltaY < 50) this.openDrawer();
  }
});
