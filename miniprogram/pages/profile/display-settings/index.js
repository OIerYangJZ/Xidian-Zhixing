import { applyThemeAndLanguage, getDisplayMode } from '../../../utils/theme_i18n';
import { setLanguage } from '../../../utils/i18n';
Page({
  data: { modeOptions: [], langOptions: [], currentModeOption: 'system' },
  onShow() { this.updateOptionsAndApply(); },
  updateOptionsAndApply() {
    applyThemeAndLanguage(this);
    const t = this.data.t;
    this.setData({
      currentModeOption: getDisplayMode(),
      modeOptions: [
        { label: t.theme_system, value: 'system' },
        { label: t.theme_light, value: 'light' },
        { label: t.theme_dark, value: 'dark' }
      ],
      langOptions: [{ label: t.lang_cn, value: 'zh-CN' }, { label: t.lang_en, value: 'en' }]
    });
  },
  onModeTap(event) {
    wx.setStorageSync('displayMode', event.currentTarget.dataset.mode);
    this.updateOptionsAndApply();
    wx.showToast({ title: this.data.t.save_success, icon: 'success' });
  },
  onLangTap(event) {
    setLanguage(event.currentTarget.dataset.lang);
    this.updateOptionsAndApply();
    wx.showToast({ title: this.data.t.save_success, icon: 'success' });
  }
});
