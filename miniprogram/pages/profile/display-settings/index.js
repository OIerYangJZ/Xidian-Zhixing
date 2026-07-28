import { applyThemeAndLanguage, getDisplayMode, getDisplayTheme } from '../../../utils/theme_i18n';
import { setLanguage, getLanguage } from '../../../utils/i18n';

Page({
  data: {
    themeOptions: [],
    modeOptions: [],
    langOptions: [],
    layoutOptions: [],
    currentThemeOption: 'zhushachi',
    currentThemeIndex: 0,
    currentThemeLabel: '人本·初创',
    currentModeOption: 'system',
    currentPostLayout: 'threads'
  },

  onShow() {
    applyThemeAndLanguage(this);
    this.updateOptionsAndApply();
  },

  updateOptionsAndApply() {
    applyThemeAndLanguage(this);
    const t = this.data.t;
    const currentThemeOption = getDisplayTheme();
    const currentModeOption = getDisplayMode();
    const currentPostLayout = wx.getStorageSync('treeholePostLayout') || 'threads';
    const themeOptions = [
      { label: t.theme_humanist_founding || '人本·初创', value: 'zhushachi' },
      { label: t.theme_academy_teal || '书院·青绿', value: 'zhuqing' },
      { label: t.theme_apricot_paper || '杏黄·纸韵', value: 'xingrenhuang' }
    ];
    const currentThemeIndex = themeOptions.findIndex((option) => option.value === currentThemeOption);
    if (currentThemeIndex < 0) {
      throw new Error(`Theme option is missing: ${currentThemeOption}`);
    }

    this.setData({
      currentThemeOption,
      currentThemeIndex,
      currentThemeLabel: themeOptions[currentThemeIndex].label,
      currentModeOption,
      currentPostLayout,
      themeOptions,
      modeOptions: [
        { label: t.theme_system || '跟随系统', value: 'system' },
        { label: t.theme_light || '浅色', value: 'light' },
        { label: t.theme_dark || '深色', value: 'dark' }
      ],
      langOptions: [
        { label: t.lang_cn || '中文', value: 'zh-CN' },
        { label: t.lang_en || 'English', value: 'en' }
      ],
      layoutOptions: [
        { label: 'Threads 极简', value: 'threads' },
        { label: '原卡片', value: 'card' }
      ]
    });
  },

  onThemeChange(event) {
    const index = Number(event.detail.value);
    const option = this.data.themeOptions[index];
    if (!option) {
      throw new Error(`Invalid theme option index: ${event.detail.value}`);
    }
    wx.setStorageSync('colorTheme', option.value);
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
  },

  onLayoutTap(event) {
    const layout = event.currentTarget.dataset.layout;
    if (!layout) return;
    wx.setStorageSync('treeholePostLayout', layout);
    this.updateOptionsAndApply();
    wx.showToast({ title: this.data.t.save_success || '已保存', icon: 'success' });
  }
});
