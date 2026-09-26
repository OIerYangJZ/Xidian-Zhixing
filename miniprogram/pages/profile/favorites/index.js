import { getFavoritePosts, unfavoritePost } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyHydratedDisplayImages, attachDisplayImages, hydrateDisplayImages } from '../../../utils/feed_images';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    loading: true,
    posts: [],
    errorMessage: ''
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadData();
  },

  onPullDownRefresh() {
    this.loadData().finally(() => wx.stopPullDownRefresh());
  },

  async loadData() {
    if (!requireLoginPage()) return;
    this.setData({ loading: true, errorMessage: '' });
    try {
      const posts = await getFavoritePosts();
      this.setData({ posts: posts.map(attachDisplayImages), loading: false });
      const hydrated = await hydrateDisplayImages(this.data.posts);
      this.setData({ posts: applyHydratedDisplayImages(this.data.posts, hydrated) });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '收藏加载失败，请重试'
      });
    }
  },

  retryLoad() {
    this.loadData();
  },

  goTagPosts(event) {
    const tag = event.currentTarget.dataset.tag;
    if (tag) wx.navigateTo({ url: `/pages/campus/search/index?keyword=${encodeURIComponent(`#${tag}`)}` });
  },

  openAuthorProfile(event) {
    const id = event.currentTarget.dataset.userId;
    if (id) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  async removeFavorite(event) {
    const index = Number(event.currentTarget.dataset.index);
    const post = this.data.posts[index];
    if (!post) return;
    try {
      await unfavoritePost(post.id);
      const posts = this.data.posts.slice();
      posts.splice(index, 1);
      this.setData({ posts });
      wx.showToast({ title: '已取消收藏', icon: 'success' });
    } catch (error) {}
  }
});
