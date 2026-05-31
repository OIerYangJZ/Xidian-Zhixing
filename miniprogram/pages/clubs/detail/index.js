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
  }
});
