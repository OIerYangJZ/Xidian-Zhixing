import { getClubDetail } from '../../../api/clubs';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { togglePostFavoriteInList, togglePostLikeInList } from '../../../utils/post_actions';

Page({
  data: { id: '', club: null, themeClass: '', errorMessage: '' },
  onLoad(options) {
    this.setData({ id: options.id || '' });
    this.loadDetail();
  },
  onShow() {
    applyThemeAndLanguage(this);
  },
  async loadDetail() {
    this.setData({ errorMessage: '' });
    try {
      this.setData({ club: await getClubDetail(this.data.id) });
    } catch (error) {
      this.setData({
        errorMessage: (error && error.message) || '社团内容加载失败，请重试'
      });
    }
  },
  retryLoad() {
    this.loadDetail();
  },
  openPost(event) {
    const id = event.detail.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },
  async togglePostLike(event) {
    const posts = await togglePostLikeInList(this.data.club.posts, event.detail.index);
    this.setData({ 'club.posts': posts });
  },
  async togglePostFavorite(event) {
    const posts = await togglePostFavoriteInList(this.data.club.posts, event.detail.index);
    this.setData({ 'club.posts': posts });
  }
});
