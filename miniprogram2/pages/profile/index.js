import { enterPage, enterContent, retainLayerExit, cancelLayerExit, clearLayerMotion } from '../../utils/motion';
import { sharePost } from '../../utils/share';
import { getUserInfo } from '../../api/auth';
import { getFavoritePosts } from '../../api/posts';
import {
  getFollowers,
  getFollowing,
  getMyComments,
  getMyPosts
} from '../../api/user';
import { avatarInitial, normalizePost, resolveUrl } from '../../utils/format';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';
import { applyHydratedDisplayImages, attachDisplayImages, hydrateDisplayImages } from '../../utils/feed_images';
import { togglePostFavoriteInList, togglePostLikeInList } from '../../utils/post_actions';

const TABS = [
  { key: 'posts', label: '帖子' },
  { key: 'activities', label: '回复' },
  { key: 'favorites', label: '收藏' }
];

const buildProfile = (raw = {}) => {
  const nickname = raw.nickname || raw.alias || '';
  return {
    ...raw,
    nickname,
    avatarInitial: avatarInitial(nickname || '匿名同学'),
    avatarUrl: resolveUrl(raw.avatarUrl || ''),
    backgroundImageUrl: resolveUrl(raw.backgroundImageUrl || '')
  };
};

const buildFollowUser = (raw = {}) => {
  const nickname = raw.nickname || raw.alias || raw.name || '西电同学';
  return {
    ...raw,
    id: String(raw.id || raw.userId || ''),
    nickname,
    avatarInitial: avatarInitial(nickname),
    avatarUrl: resolveUrl(raw.avatarUrl || ''),
    isMutual: Boolean(raw.isFollowing && raw.isFollower)
  };
};

const buildPost = (raw = {}) => {
  const normalized = normalizePost(raw);
  return {
    ...normalized,
    images: normalized.imageUrls,
    isLiked: normalized.liked
  };
};

Page({
  onShareAppMessage: sharePost,
  data: {
    tabs: TABS,
    activeTab: 'posts',
    userInfo: null,
    followers: [],
    following: [],
    posts: [],
    favoritePosts: [],
    comments: [],
    loadingProfile: true,
    loadingPosts: true,
    loadingFavorites: true,
    loadingComments: true,
    profileError: '',
    postsError: '',
    favoritesError: '',
    commentsError: '',
    showFollowSheet: false,
    followSheetTitle: '',
    followSheetUsers: [],
    followSheetMutualUsers: [],
    followSheetOtherUsers: [],
    navTop: 0,
    navHeight: 48
  },

  onLoad() {
    this._tabScrollTops = { posts: 0, favorites: 0, activities: 0 };
    this._didInitialShow = false;
    applyThemeAndLanguage(this);
    this.initCustomNav();
    if (!requireLoginPage()) return;
    this.loadInitialData().catch((error) => {
      console.error('[profile initial load failed]', error);
    });
  },

  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
    this.initCustomNav();
    if (!requireLoginPage()) return;
    if (!this._didInitialShow) {
      this._didInitialShow = true;
      return;
    }
    this.refreshProfile().catch((error) => {
      console.error('[profile refresh failed]', error);
    });
  },

  initCustomNav() {
    const app = getApp();
    this.setData({
      navTop: app.globalData.navTop || 44,
      navRight: app.globalData.navRight,
      navHeight: app.globalData.navHeight || 32
    });
  },

  goBack() {
    const pages = getCurrentPages();
    if (pages.length > 1) {
      wx.navigateBack();
      return;
    }
    wx.switchTab({ url: '/pages/treehole/index' });
  },

  onPullDownRefresh() {
    this.refreshAll()
      .catch((error) => {
        console.error('[profile pull refresh failed]', error);
      })
      .finally(() => wx.stopPullDownRefresh());
  },

  onPageScroll(event) {
    if (!this._tabScrollTops) return;
    this._tabScrollTops[this.data.activeTab] = event.scrollTop || 0;
  },

  loadInitialData() {
    return Promise.all([
      this.refreshProfile(),
      this.loadPosts(),
      this.loadFavorites(),
      this.loadComments()
    ]);
  },

  refreshAll() {
    return Promise.all([
      this.refreshProfile(),
      this.loadPosts(),
      this.loadFavorites(),
      this.loadComments()
    ]);
  },

  async refreshProfile() {
    this.setData({ loadingProfile: true, profileError: '' });
    try {
      const [profileResponse, followers, following] = await Promise.all([
        getUserInfo(),
        getFollowers(),
        getFollowing()
      ]);
      this.setData({
        userInfo: buildProfile(profileResponse.data),
        followers: followers.map(buildFollowUser),
        following: following.map(buildFollowUser)
      });
    } catch (error) {
      this.setData({ profileError: '个人资料或关注数据加载失败，请重试' });
    } finally {
      this.setData({ loadingProfile: false });
    }
  },

  async loadPosts() {
    this.setData({ loadingPosts: true, postsError: '' });
    try {
      const posts = await getMyPosts();
      this.setData({
        posts: posts.map((post) => attachDisplayImages(buildPost(post)))
      });
      await this.hydrateProfileImages('posts');
    } catch (error) {
      this.setData({ postsError: '帖子加载失败，请重试' });
    } finally {
      this.setData({ loadingPosts: false });
    }
  },

  async loadFavorites() {
    this.setData({ loadingFavorites: true, favoritesError: '' });
    try {
      const posts = await getFavoritePosts();
      this.setData({
        favoritePosts: posts.map((post) => attachDisplayImages(buildPost(post)))
      });
      await this.hydrateProfileImages('favoritePosts');
    } catch (error) {
      this.setData({ favoritesError: '收藏加载失败，请重试' });
    } finally {
      this.setData({ loadingFavorites: false });
    }
  },

  async hydrateProfileImages(key) {
    const posts = this.data[key] || [];
    const hydratedByPostId = await hydrateDisplayImages(posts);
    const hydratedPosts = applyHydratedDisplayImages(this.data[key] || [], hydratedByPostId);
    if (hydratedPosts !== this.data[key]) {
      this.setData({ [key]: hydratedPosts });
    }
  },

  async loadComments() {
    this.setData({ loadingComments: true, commentsError: '' });
    try {
      const comments = await getMyComments();
      this.setData({
        comments: comments.map((item = {}) => ({
          ...item,
          id: String(item.id || item.commentId || ''),
          postId: String(item.postId || ''),
          postTitle: item.postTitle || '原帖',
          content: item.content || '',
          timeText: item.timeText || ''
        }))
      });
    } catch (error) {
      this.setData({ commentsError: '评论动态加载失败，请重试' });
    } finally {
      this.setData({ loadingComments: false });
    }
  },

  switchProfileTab(event) {
    const tab = event.currentTarget.dataset.tab;
    if (!TABS.some(item => item.key === tab) || tab === this.data.activeTab) return;
    const direction = TABS.findIndex(item => item.key === tab) - TABS.findIndex(item => item.key === this.data.activeTab);
    this._tabScrollTops[this.data.activeTab] = this._tabScrollTops[this.data.activeTab] || 0;
    enterContent(this, { activeTab: tab }, direction, () => {
      wx.pageScrollTo({
        scrollTop: this._tabScrollTops[tab] || 0,
        duration: 0
      });
    });
  },

  goToEditProfile() {
    if (!requireLoginPage()) return;
    wx.navigateTo({ url: '/pages/profile/edit-profile/index' });
  },

  goToSettings() {
    if (!requireLoginPage()) return;
    wx.navigateTo({ url: '/pages/profile/settings/index' });
  },

  openFollowSheet(event) {
    cancelLayerExit(this, 'showFollowSheet');
    if (this.data.profileError) {
      wx.showToast({ title: '关注数据尚未加载，请先重试', icon: 'none' });
      return;
    }
    const type = event.currentTarget.dataset.type;
    const users = type === 'following' ? this.data.following : this.data.followers;
    const title = type === 'following' ? '关注' : '粉丝';
    const mutual = users.filter((item) => item.isMutual);
    const others = users.filter((item) => !item.isMutual);
    this.setData({
      showFollowSheet: true,
      followSheetTitle: title,
      followSheetUsers: users,
      followSheetMutualUsers: mutual,
      followSheetOtherUsers: others
    });
  },

  closeFollowSheet() {
    retainLayerExit(this, 'showFollowSheet', () => {
      this.setData({ followSheetTitle: '', followSheetUsers: [], followSheetMutualUsers: [], followSheetOtherUsers: [] });
    });
    this.setData({ showFollowSheet: false });
  },

  onHide() { this.closeFollowSheet(); clearLayerMotion(this); },
  onUnload() { this.closeFollowSheet(); clearLayerMotion(this); },

  openFollowUser(event) {
    const id = event.currentTarget.dataset.id;
    if (!id) return;
    this.closeFollowSheet();
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${encodeURIComponent(id)}` });
  },

  stopTouchMove() {},

  goPostDetail(event) {
    const id = event.detail.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  openCommentDetail(event) {
    const postId = event.currentTarget.dataset.postId;
    const commentId = event.currentTarget.dataset.commentId;
    if (!postId) return;
    wx.navigateTo({
      url: `/pages/campus/post-detail/index?id=${postId}${commentId ? `&commentId=${commentId}` : ''}`
    });
  },

  async toggleLike(event) {
    const key = event.detail.listKey || 'posts';
    const posts = await togglePostLikeInList(this.data[key], event.detail.index);
    this.setData({ [key]: posts });
  },

  async toggleFavorite(event) {
    const key = event.detail.listKey || 'posts';
    const posts = await togglePostFavoriteInList(this.data[key], event.detail.index);
    this.setData({ [key]: posts });
  },

  previewPostImage(event) {
    const source = event.detail.listKey;
    const postIndex = Number(event.detail.index);
    const current = event.detail.url;
    const posts = this.data[source] || [];
    const post = posts[postIndex];
    const urls = (post && (post.displayImages || post.imageUrls)) || [];
    if (current && urls.length) {
      wx.previewImage({ current, urls });
    }
  },

  showShareToast() {
    wx.showToast({ title: '链接已复制', icon: 'none', duration: 1000 });
  }
});
