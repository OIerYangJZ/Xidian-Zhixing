import { getClubDetail } from '../../../api/clubs';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: { id: '', club: null, themeClass: '' },
  onLoad(options) {
    this.setData({ id: options.id || '' });
    this.loadDetail();
  },
  onShow() {
    applyThemeAndLanguage(this);
  },
  async loadDetail() {
    this.setData({ club: await getClubDetail(this.data.id) });
  },
  openPost(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  }
});
