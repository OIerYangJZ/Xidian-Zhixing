import { getClubs } from '../../api/clubs';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';

Page({
  data: { clubs: [], themeClass: '', loading: true, errorMessage: '' },
  async onLoad() {
    await this.loadClubs();
  },
  async loadClubs() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const clubs = (await getClubs()).map((club) => Object.assign({}, club, {
        initial: String(club.name || '社').trim().charAt(0) || '社'
      }));
      this.setData({ clubs, loading: false });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '社团列表加载失败，请重试'
      });
    }
  },
  retryLoad() {
    this.loadClubs();
  },
  onShow() {
    applyThemeAndLanguage(this);
  },
  openDetail(event) {
    if (!event.currentTarget.dataset.id) return;
    wx.navigateTo({ url: `/pages/clubs/detail/index?id=${event.currentTarget.dataset.id}` });
  },
  apply() {
    wx.navigateTo({ url: '/pages/clubs/apply/index' });
  }
});
