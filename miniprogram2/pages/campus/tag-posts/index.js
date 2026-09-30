import { enterPage } from '../../../utils/motion';
import { sharePost } from '../../../utils/share';
import { getUserInfo } from '../../../api/auth';
import { getPosts } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { applyHydratedDisplayImages, attachDisplayImages, hydrateDisplayImages } from '../../../utils/feed_images';
import { togglePostFavoriteInList, togglePostLikeInList } from '../../../utils/post_actions';

const escapeRegExp = (value) => String(value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const postHasTag = (post, tag) => {
  const cleanTag = String(tag || '').trim();
  if (!cleanTag) return false;
  if ((post.tags || []).some((item) => String(item || '').trim() === cleanTag)) return true;
  const pattern = new RegExp(`(^|\\s)#${escapeRegExp(cleanTag)}(?=\\s|$)`);
  return pattern.test(`${post.title || ''} ${post.content || ''}`);
};

Page({
  onShareAppMessage: sharePost,
  data: {
    tag: '',
    posts: [],
    total: 0,
    loading: true,
    themeClass: '',
    navTop: 0,
    navHeight: 32,
    navRight: 100,
    currentUserId: '',
    errorMessage: ''
  },

  async onLoad(options) {
    this.initCustomNav();
    applyThemeAndLanguage(this);
    const tag = decodeURIComponent(options.tag || '').replace(/^#+/, '').trim();
    this.setData({ tag });
    if (!requireLoginPage()) return;
    try {
      await this.loadUserInfo();
      if (tag) await this.loadPosts();
      if (!tag) this.setData({ loading: false });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '标签页面加载失败，请重试'
      });
    }
  },

  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
    this.initCustomNav();
  },

  async loadUserInfo() {
    const response = await getUserInfo();
    const user = response.data || {};
    this.setData({ currentUserId: String(user.id || '').trim() });
  },

  initCustomNav() {
    const app = getApp();
    this.setData({
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32,
      navRight: app.globalData.navRight
    });
  },

  async loadPosts() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const posts = await getPosts({
        keyword: this.data.tag,
        sort: 'latest'
      });
      const filteredPosts = posts
        .filter((post) => postHasTag(post, this.data.tag))
        .map((post) => {
          const authorUserId = String(post.authorUserId || post.authorId || '').trim();
          const isFollowingAuthor = Boolean(post.followingAuthor || post.isFollowingAuthor || post.isFollowing);
          return attachDisplayImages({
            ...post,
            canShowFollowDot: Boolean(authorUserId && !post.isAnonymous && authorUserId !== this.data.currentUserId && !isFollowingAuthor)
          });
        });
      this.setData({
        posts: filteredPosts,
        total: filteredPosts.length
      });
      await this.hydrateFeedImages();
    } catch (error) {
      this.setData({
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '标签帖子加载失败，请重试'
      });
    } finally {
      this.setData({ loading: false });
    }
  },

  retryLoad() {
    this.loadPosts();
  },

  async hydrateFeedImages() {
    const posts = this.data.posts;
    const hydratedByPostId = await hydrateDisplayImages(posts);
    const hydratedPosts = applyHydratedDisplayImages(this.data.posts, hydratedByPostId);
    if (hydratedPosts !== this.data.posts) {
      this.setData({ posts: hydratedPosts });
    }
  },

  goPostDetail(event) {
    const id = event.detail.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  goBack() {
    if (getCurrentPages().length > 1) wx.navigateBack({ delta: 1 });
    else wx.switchTab({ url: '/pages/treehole/index' });
  },

  goTagPosts(event) {
    const tag = event.detail.tag;
    if (tag) wx.navigateTo({ url: `/pages/campus/tag-posts/index?tag=${encodeURIComponent(tag)}` });
  },

  async togglePostLike(event) {
    const index = Number(event.detail.index);
    const posts = await togglePostLikeInList(this.data.posts, index);
    this.setData({ posts });
  },

  async togglePostFavorite(event) {
    const index = Number(event.detail.index);
    const posts = await togglePostFavoriteInList(this.data.posts, index);
    this.setData({ posts });
  },

  openAuthorProfile(event) {
    const userId = event.detail.userId || '';
    const isAnonymous = String(event.detail.anonymous || '0') === '1';
    if (!userId || isAnonymous) return;
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${userId}` });
  }
});
