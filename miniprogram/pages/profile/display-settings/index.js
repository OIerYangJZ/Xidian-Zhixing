import { applyThemeAndLanguage, getDisplayMode } from '../../../utils/theme_i18n';
import { setLanguage, getLanguage } from '../../../utils/i18n';

Page({
  data: {
    themeOptions: [],
    modeOptions: [],
    langOptions: [],
    currentThemeOption: 'zhushachi',
    currentModeOption: 'system'
  },

  onShow() {
    applyThemeAndLanguage(this);
    this.updateOptionsAndApply();
  },

  updateOptionsAndApply() {
    applyThemeAndLanguage(this);
    const t = this.data.t;
    const currentThemeOption = wx.getStorageSync('colorTheme') || 'zhushachi';
    const currentModeOption = getDisplayMode();

    this.setData({
      currentThemeOption,
      currentModeOption,
      themeOptions: [
        { label: '朱砂赤', value: 'zhushachi' },
        { label: '胭脂红', value: 'yanzhihong' },
        { label: '赤陶暖', value: 'chitaonuan' },
        { label: '枣泥红', value: 'zaonihong' },
        { label: '宣纸朱', value: 'xuanzhizhu' },
        { label: '竹青', value: 'zhuqing' },
        { label: '藕荷紫', value: 'ouhezi' },
        { label: '杏仁黄', value: 'xingrenhuang' },
        { label: '海盐青', value: 'haiyanqing' },
        { label: '墨灰', value: 'mohui' },
        { label: '极简', value: 'minimal' }
      ],
      modeOptions: [
        { label: t.theme_system || '跟随系统', value: 'system' },
        { label: t.theme_light || '浅色', value: 'light' },
        { label: t.theme_dark || '深色', value: 'dark' }
      ],
      langOptions: [
        { label: t.lang_cn || '简体中文', value: 'zh-CN' },
        { label: t.lang_tw || '繁體中文', value: 'zh-TW' },
        { label: t.lang_en || 'English', value: 'en' }
      ]
    });
  },

  onThemeTap(event) {
    const theme = event.currentTarget.dataset.theme;
    if (!theme) return;
    wx.setStorageSync('colorTheme', theme);
    this.updateOptionsAndApply();
    wx.showToast({ title: this.data.t.save_success || '已保存', icon: 'success' });
  },

  onModeTap(event) {
    const mode = event.currentTarget.dataset.mode;
    if (!mode) return;
    wx.setStorageSync('displayMode', mode);
    this.updateOptionsAndApply();
    wx.showToast({ title: this.data.t.save_success || '已保存', icon: 'success' });
  },

  onLangTap(event) {
    const lang = event.currentTarget.dataset.lang;
    if (!lang) return;
    setLanguage(lang);
    this.updateOptionsAndApply();
    wx.showToast({ title: this.data.t.save_success || '已保存', icon: 'success' });
  }
});
