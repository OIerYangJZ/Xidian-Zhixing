import { enterPage } from '../../../utils/motion';
import { sharePost } from '../../../utils/share';
import { getFavoritePosts, unfavoritePost } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { togglePostLikeInList } from '../../../utils/post_actions';

Page({
  onShareAppMessage: sharePost,
  data: {
    loading: true,
    posts: [],
    errorMessage: ''
  },

  onShow() {
    enterPage(this);
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
      this.setData({ posts, loading: false });
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

  goPostDetail(event) {
    const id = event.detail.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  async togglePostLike(event) {
    const posts = await togglePostLikeInList(this.data.posts, event.detail.index);
    this.setData({ posts });
  },

  async removeFavorite(event) {
    const index = Number(
      event.detail && event.detail.index !== undefined
        ? event.detail.index
        : event.currentTarget.dataset.index
    );
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
