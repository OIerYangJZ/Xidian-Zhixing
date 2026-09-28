import { getUserInfo } from '../../api/auth';
import { getPosts } from '../../api/post';
import { favoritePost, setPostLiked, setPostReposted, unfavoritePost } from '../../api/posts';
import { getSectionsTree } from '../../api/campus';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';
import { avatarInitial, listRow } from '../../utils/format';
import { attachDisplayImages, hydrateDisplayImages } from '../../utils/feed_images';

const SORT_OPTIONS = [
  { label: '最新', value: 'latest' },
  { label: '热度', value: 'hot' }
];

// request.js already toasts HTTP and network failures; a response that fails
// its shape check is an Error it never saw.
const toastContractError = (error) => {
  if (error instanceof Error) wx.showToast({ title: error.message, icon: 'none' });
};

Page({
  data: {
    posts: [],
    sectionTree: { sections: [], colleges: [], clubs: [] },
    postLayout: 'threads',
    loading: false,
    hasMore: true,
    page: 1,
    limit: 10,
    activeSection: null,
    sortOptions: SORT_OPTIONS,
    activeSort: 'latest',
    showPublishButton: true,
    showFilterMenu: false,
    refreshTriggered: false,
    refreshFeedbackVisible: false,
    drawerOpen: false,
    touchStartX: 0,
    touchStartY: 0,
    navTop: 0,
    navHeight: 48,
    userInfo: null,
    errorMessage: ''
  },

  onLoad() {
    this.initCustomNav();
    this.loadPostLayout();
    setTimeout(() => this.initialLoad(), 0);
  },

  onShow() {
    applyThemeAndLanguage(this);
    this.initCustomNav();
    this.loadPostLayout();
    // First launch goes to the login page from onLoad; coming back from it
    // only runs onShow, so the first load happens here.
    if (this._loadedOnce === false) this.initialLoad();
  },

  async initialLoad() {
    if (!requireLoginPage()) {
      this._loadedOnce = false;
      return;
    }
    this._loadedOnce = true;
    try {
      await Promise.all([this.loadUserInfo(), this.loadSections()]);
      await this.fetchPosts();
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '页面加载失败，请重试'
      });
    }
  },

  onPullDownRefresh() {
    this.refreshFeed({ stopPageRefresh: true });
  },

  initCustomNav() {
    const app = getApp();
    this.setData({
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32
    });
  },

  loadPostLayout() {
    this.setData({ postLayout: wx.getStorageSync('treeholePostLayout') || 'threads' });
  },

  async loadSections() {
    const response = await getSectionsTree();
    const tree = response.data || response || {};
    const sections = [
      ...(tree.sections || []),
      ...(tree.colleges || []),
      ...(tree.clubs || [])
    ];
    const dedupedSections = [];
    sections.forEach((section) => {
      if (!dedupedSections.some((item) => item.sectionId === section.sectionId)) {
        dedupedSections.push(section);
      }
    });
    this.setData({ sectionTree: { ...tree, sections: dedupedSections } });
  },

  async loadUserInfo() {
    const response = await getUserInfo();
    const user = response.data;
    this.setData({
      userInfo: {
        ...user,
        avatarInitial: avatarInitial(user.nickname || user.alias)
      }
    });
  },

  selectSection(event) {
    const section = event.currentTarget.dataset.section;
    this.setData({
      activeSection: section || null,
      posts: [],
      loading: false,
      page: 1,
      hasMore: true,
      showFilterMenu: false
    }, () => this.fetchPosts({ restart: true }));
  },

  clearActiveSection() {
    this.setData({
      activeSection: null,
      posts: [],
      loading: false,
      page: 1,
      hasMore: true
    }, () => this.fetchPosts({ restart: true }));
  },

  onSortTap(event) {
    const sort = event.currentTarget.dataset.sort;
    if (!sort) return;
    this.setData({
      activeSort: sort,
      posts: [],
      loading: false,
      page: 1,
      hasMore: true,
      showFilterMenu: false
    }, () => this.fetchPosts({ restart: true }));
  },

  toggleFilterMenu() {
    this.setData({ showFilterMenu: !this.data.showFilterMenu });
  },

  closeFilterMenu() {
    this.setData({ showFilterMenu: false });
  },

  refreshFeed(options = {}) {
    this.setData({
      refreshTriggered: true,
      refreshFeedbackVisible: true,
      page: 1,
      posts: [],
      hasMore: true,
      loading: false,
      errorMessage: ''
    }, () => {
      Promise.all([this.loadSections(), this.fetchPosts({ restart: true })])
        .catch((error) => {
          console.error('[treehole refresh failed]', error);
          this.setData({
            errorMessage: (error && error.data && error.data.message)
              || (error && error.message)
              || '刷新失败，请重试'
          });
        })
        .finally(() => {
          if (options.stopPageRefresh) wx.stopPullDownRefresh();
          this.setData({ refreshTriggered: false });
          setTimeout(() => {
            this.setData({ refreshFeedbackVisible: false });
          }, 350);
        });
    });
  },

  onRefresherRefresh() {
    this.refreshFeed();
  },

  // One feed "generation" per filter: an answer for an older section, sort
  // or refresh is dropped instead of landing in the new list.
  async fetchPosts({ restart = false } = {}) {
    if (restart) this._feedGeneration = (this._feedGeneration || 0) + 1;
    const generation = this._feedGeneration || 0;
    if (!restart && (this.data.loading || !this.data.hasMore)) return;
    const params = {
      page: this.data.page,
      limit: this.data.limit,
      sort: this.data.activeSort
    };
    if (this.data.activeSection) {
      params.sectionId = this.data.activeSection.sectionId;
      params.sectionType = this.data.activeSection.sectionType;
    }

    this.setData({ loading: true, errorMessage: '' });
    try {
      const res = await getPosts(params);
      if (generation !== (this._feedGeneration || 0)) return;
      const currentUserId = String((this.data.userInfo && this.data.userInfo.id) || '').trim();
      const newPosts = ((res.data && res.data.items) || []).map((post) => {
        const authorUserId = String(post.authorUserId || post.authorId || '').trim();
        const isFollowingAuthor = Boolean(post.followingAuthor || post.isFollowingAuthor || post.isFollowing);
        return attachDisplayImages(listRow({
          ...post,
          canShowFollowDot: Boolean(authorUserId && !post.isAnonymous && authorUserId !== currentUserId && !isFollowingAuthor)
        }));
      });
      // Only the new rows go over setData, by path, not the whole list again;
      // a post already shown (offset paging after new posts) is skipped.
      const shown = new Set(this.data.posts.map((post) => post.id));
      const patch = {};
      let at = this.data.posts.length;
      newPosts.filter((post) => !shown.has(post.id)).forEach((post) => {
        patch[`posts[${at}]`] = post;
        at += 1;
      });
      this.setData({
        ...patch,
        page: this.data.page + 1,
        hasMore: res.data && res.data.hasMore !== undefined ? res.data.hasMore : newPosts.length >= this.data.limit,
        loading: false
      });
      await this.hydrateFeedImages();
    } catch (error) {
      if (generation !== (this._feedGeneration || 0)) return;
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '帖子加载失败，请重试'
      });
    }
  },

  async hydrateFeedImages() {
    const posts = this.data.posts;
    const hydratedByPostId = await hydrateDisplayImages(posts);
    const patch = {};
    this.data.posts.forEach((post, index) => {
      const images = hydratedByPostId[String(post.id || '')];
      if (images) patch[`posts[${index}].displayImages`] = images;
    });
    if (Object.keys(patch).length) this.setData(patch);
  },

  onReachBottom() {
    this.fetchPosts();
  },

  retryFeed() {
    this.setData({ page: 1, posts: [], hasMore: true, loading: false, errorMessage: '' }, () => {
      this.fetchPosts({ restart: true });
    });
  },

  onScroll(event) {
    const scrollTop = event.detail.scrollTop;
    if (this._lastScrollTop == null) this._lastScrollTop = scrollTop;
    if (scrollTop > this._lastScrollTop + 20 && this.data.showPublishButton) {
      this.setData({ showPublishButton: false });
    }
    if (scrollTop < this._lastScrollTop - 20 && !this.data.showPublishButton) {
      this.setData({ showPublishButton: true });
    }
    this._lastScrollTop = scrollTop;
  },

  goPostDetail(event) {
    wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${event.currentTarget.dataset.id}` });
  },

  goTagPosts(event) {
    const tag = event.currentTarget.dataset.tag;
    if (!tag) return;
    wx.navigateTo({ url: `/pages/campus/search/index?keyword=${encodeURIComponent(`#${tag}`)}` });
  },

  async togglePostLike(event) {
    const index = Number(event.currentTarget.dataset.index);
    const post = this.data.posts[index];
    if (!post || !post.id) return;
    let result;
    try {
      result = await setPostLiked(post.id, !post.liked);
    } catch (error) {
      toastContractError(error);
      return;
    }
    this.setData({
      [`posts[${index}].liked`]: result.liked,
      [`posts[${index}].isLiked`]: result.liked,
      [`posts[${index}].likeCount`]: result.likeCount
    });
  },

  async togglePostFavorite(event) {
    const index = Number(event.currentTarget.dataset.index);
    const post = this.data.posts[index];
    if (!post || !post.id) return;
    const favorited = Boolean(post.favorited || post.isFavorited);
    let result;
    try {
      result = favorited ? await unfavoritePost(post.id) : await favoritePost(post.id);
    } catch (error) {
      toastContractError(error);
      return;
    }
    this.setData({
      [`posts[${index}].favorited`]: result.favorited,
      [`posts[${index}].isFavorited`]: result.favorited,
      [`posts[${index}].favoriteCount`]: result.favoriteCount
    });
  },

  async togglePostRepost(event) {
    const index = Number(event.currentTarget.dataset.index);
    const post = this.data.posts[index];
    if (!post || !post.id || this._reposting) return;
    this._reposting = true;
    let result;
    try {
      result = await setPostReposted(post.id, !post.reposted);
    } catch (error) {
      toastContractError(error);
      return;
    } finally {
      this._reposting = false;
    }
    this.setData({
      [`posts[${index}].reposted`]: result.reposted,
      [`posts[${index}].repostCount`]: result.repostCount
    });
    wx.showToast({ title: result.reposted ? '已转发到你的主页' : '已取消转发', icon: 'none' });
  },

  openAuthorProfile(event) {
    const userId = event.currentTarget.dataset.userId || '';
    const isAnonymous = String(event.currentTarget.dataset.anonymous || '0') === '1';
    if (!userId || isAnonymous) return;
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${userId}` });
  },

  goSearch() {
    wx.navigateTo({ url: '/pages/campus/search/index' });
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
    const touch = event.touches && event.touches[0];
    if (!touch) return;
    this.setData({ touchStartX: touch.clientX, touchStartY: touch.clientY });
  },

  onTouchEnd(event) {
    const touch = event.changedTouches && event.changedTouches[0];
    if (!touch) return;
    const deltaX = touch.clientX - this.data.touchStartX;
    const deltaY = Math.abs(touch.clientY - this.data.touchStartY);
    if (this.data.touchStartX < 24 && deltaX > 70 && deltaY < 50) this.openDrawer();
  }
});
