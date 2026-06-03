import { favoritePost, getPosts, togglePostLike, unfavoritePost } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const escapeRegExp = (value) => String(value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const postHasTag = (post, tag) => {
  const cleanTag = String(tag || '').trim();
  if (!cleanTag) return false;
  if ((post.tags || []).some((item) => String(item || '').trim() === cleanTag)) return true;
  const pattern = new RegExp(`(^|\\s)#${escapeRegExp(cleanTag)}(?=\\s|$)`);
  return pattern.test(`${post.title || ''} ${post.content || ''}`);
};

Page({
  data: {
    tag: '',
    posts: [],
    total: 0,
    loading: true,
    themeClass: '',
    navTop: 0,
    navHeight: 32
  },

  onLoad(options) {
    this.initCustomNav();
    applyThemeAndLanguage(this);
    const tag = decodeURIComponent(options.tag || '').replace(/^#+/, '').trim();
    this.setData({ tag });
    if (!requireLoginPage()) return;
    if (tag) this.loadPosts();
    if (!tag) this.setData({ loading: false });
  },

  onShow() {
    applyThemeAndLanguage(this);
    this.initCustomNav();
  },

  initCustomNav() {
    const app = getApp();
    this.setData({
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32
    });
  },

  async loadPosts() {
    this.setData({ loading: true });
    try {
      const posts = await getPosts({
        keyword: this.data.tag,
        sort: 'latest'
      });
      const filteredPosts = posts.filter((post) => postHasTag(post, this.data.tag));
      this.setData({
        posts: filteredPosts,
        total: filteredPosts.length
      });
    } finally {
      this.setData({ loading: false });
    }
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  goBack() {
    wx.navigateBack();
  },

  goTagPosts(event) {
    const tag = event.currentTarget.dataset.tag;
    if (tag) wx.navigateTo({ url: `/pages/campus/tag-posts/index?tag=${encodeURIComponent(tag)}` });
  },

  async togglePostLike(event) {
    const index = Number(event.currentTarget.dataset.index);
    const post = this.data.posts[index];
    if (!post || !post.id) return;
    const result = await togglePostLike(post.id);
    const liked = Boolean(result.liked);
    const posts = this.data.posts.slice();
    posts[index] = {
      ...post,
      liked,
      isLiked: liked,
      likeCount: Math.max(0, Number(post.likeCount || 0) + (liked ? 1 : -1))
    };
    this.setData({ posts });
  },

  async togglePostFavorite(event) {
    const index = Number(event.currentTarget.dataset.index);
    const post = this.data.posts[index];
    if (!post || !post.id) return;
    const favorited = Boolean(post.favorited || post.isFavorited);
    const result = favorited ? await unfavoritePost(post.id) : await favoritePost(post.id);
    const nextFavorited = !favorited;
    const posts = this.data.posts.slice();
    posts[index] = {
      ...post,
      favorited: nextFavorited,
      isFavorited: nextFavorited,
      favoriteCount: Number(result.favoriteCount)
    };
    this.setData({ posts });
  },

  openAuthorProfile(event) {
    const userId = event.currentTarget.dataset.userId || '';
    const isAnonymous = String(event.currentTarget.dataset.anonymous || '0') === '1';
    if (!userId || isAnonymous) return;
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${userId}` });
  }
});
