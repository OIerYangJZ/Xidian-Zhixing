import { getClubs } from '../../api/clubs';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';

Page({
  data: { clubs: [], themeClass: '' },
  async onLoad() {
    this.setData({ clubs: await getClubs() });
  },
  onShow() {
    applyThemeAndLanguage(this);
  },
  openDetail(event) {
    wx.navigateTo({ url: `/pages/clubs/detail/index?id=${event.currentTarget.dataset.id}` });
  },
  apply() {
    wx.navigateTo({ url: '/pages/clubs/apply/index' });
  }
});
