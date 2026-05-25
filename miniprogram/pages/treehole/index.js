import { getPosts } from '../../api/post';
import { getChannels } from '../../api/posts';
import { getSectionsTree } from '../../api/campus';
import { getClubs } from '../../api/clubs';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';

const SORT_OPTIONS = [
  { label: '最新', value: 'latest' },
  { label: '热度', value: 'hot' }
];

Page({
  data: {
    currentTab: 'community',
    posts: [],
    sectionTree: { school: null, colleges: [], channels: [], clubs: [] },
    clubs: [],
    loading: false,
    hasMore: true,
    page: 1,
    limit: 10,
    channels: ['全部'],
    activeChannel: '全部',
    activeSection: null,
    sortOptions: SORT_OPTIONS,
    activeSort: 'latest',
    showPublishButton: true,
    showChannelMenu: false,
    drawerOpen: false,
    touchStartX: 0,
    touchStartY: 0,
    navTop: 0,
    navHeight: 48
  },

  onLoad() {
    this.initCustomNav();
    setTimeout(() => {
      if (!requireLoginPage()) return;
      this.loadChannels();
      this.loadSections();
      this.loadClubs();
      this.fetchPosts();
    }, 0);
  },

  onShow() {
    applyThemeAndLanguage(this);
    this.initCustomNav();
  },

  onPullDownRefresh() {
    this.setData({ page: 1, posts: [], hasMore: true }, () => {
      Promise.all([this.loadSections(), this.loadClubs(), this.fetchPosts()])
        .finally(() => wx.stopPullDownRefresh());
    });
  },

  initCustomNav() {
    const menuButton = wx.getMenuButtonBoundingClientRect();
    this.setData({ navTop: menuButton.top, navHeight: menuButton.height });
  },

  async loadChannels() {
    const channels = await getChannels();
    this.setData({ channels: ['全部', ...channels.filter((item) => item !== '全部')] });
  },

  async loadSections() {
    const response = await getSectionsTree();
    this.setData({ sectionTree: response.data || response || { school: null, colleges: [], channels: [], clubs: [] } });
  },

  async loadClubs() {
    const clubs = await getClubs();
    this.setData({ clubs });
  },

  switchTab(event) {
    const tab = event.currentTarget.dataset.tab;
    if (!tab || tab === this.data.currentTab) return;
    this.setData({ currentTab: tab, showChannelMenu: false });
  },

  selectSection(event) {
    const section = event.currentTarget.dataset.section;
    this.setData({
      activeSection: section || null,
      currentTab: 'community',
      posts: [],
      page: 1,
      hasMore: true,
      showChannelMenu: false
    }, () => this.fetchPosts());
  },

  onChannelTap(event) {
    const channel = event.currentTarget.dataset.channel;
    if (!channel) return;
    this.setData({
      activeChannel: channel,
      activeSection: null,
      posts: [],
      page: 1,
      hasMore: true,
      showChannelMenu: false
    }, () => this.fetchPosts());
  },

  onSortTap(event) {
    const sort = event.currentTarget.dataset.sort;
    if (!sort) return;
    this.setData({
      activeSort: sort,
      posts: [],
      page: 1,
      hasMore: true,
      showChannelMenu: false
    }, () => this.fetchPosts());
  },

  toggleChannelMenu() {
    this.setData({ showChannelMenu: !this.data.showChannelMenu });
  },

  closeChannelMenu() {
    this.setData({ showChannelMenu: false });
  },

  async fetchPosts() {
    if (this.data.loading || !this.data.hasMore) return;
    const params = {
      page: this.data.page,
      limit: this.data.limit,
      sort: this.data.activeSort
    };
    if (this.data.activeChannel !== '全部') params.channel = this.data.activeChannel;
    if (this.data.activeSection) {
      params.sectionId = this.data.activeSection.sectionId || this.data.activeSection.id;
      params.sectionType = this.data.activeSection.sectionType;
    }

    this.setData({ loading: true });
    try {
      const res = await getPosts(params);
      const newPosts = (res.data && res.data.items) || [];
      this.setData({
        posts: this.data.posts.concat(newPosts),
        page: this.data.page + 1,
        hasMore: res.data && res.data.hasMore !== undefined ? res.data.hasMore : newPosts.length >= this.data.limit,
        loading: false
      });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  onReachBottom() {
    if (this.data.currentTab === 'community') this.fetchPosts();
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

  goToDetail(event) {
    wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${event.currentTarget.dataset.id}` });
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

  goHot() {
    wx.navigateTo({ url: '/pages/treehole/hot/index' });
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
