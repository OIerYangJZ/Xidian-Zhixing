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
    // The four themes every client offers; swatches are bg, primary, accent
    // from styles/zx-tokens.wxss.
    const themeOptions = [
      { label: t.theme_humanist_founding || '人本·初创', value: 'zhushachi', desc: '朱赤、暖白与杏黄', swatches: ['#F7F6F2', '#A43B32', '#E8B65D'] },
      { label: t.theme_academy_teal || '书院·青绿', value: 'zhuqing', desc: '沉静青绿与纸白', swatches: ['#F3F7F2', '#426F52', '#D4A955'] },
      { label: t.theme_apricot_paper || '杏黄·纸韵', value: 'xingrenhuang', desc: '古朴杏黄与墨褐', swatches: ['#FBF6EA', '#94631F', '#E3B660'] },
      { label: t.theme_ink_page || '墨朱·新页', value: 'mozhuxinye', desc: '连续讨论流与墨朱金', swatches: ['#FFFFFF', '#AB3E36', '#E6B75D'] }
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
      currentLanguage: getLanguage(),
      themeOptions,
      modeOptions: [
        { label: t.theme_system || '跟随系统', value: 'system' },
        { label: t.theme_light || '浅色', value: 'light' },
        { label: t.theme_dark || '深色', value: 'dark' }
      ],
      langOptions: [
        { label: '简体中文', value: 'zh-CN' },
        { label: t.lang_en || 'English', value: 'en' }
      ],
      layoutOptions: [
        { label: 'Threads 极简', value: 'threads' },
        { label: '原卡片', value: 'card' }
      ]
    });
  },

  onThemeTap(event) {
    const index = Number(event.currentTarget.dataset.index);
    const option = this.data.themeOptions[index];
    if (!option) {
      throw new Error(`Invalid theme option index: ${event.detail.value}`);
    }
    wx.setStorageSync('colorTheme', option.value);
    this.updateOptionsAndApply();
  },

  onModeTap(event) {
    const mode = event.currentTarget.dataset.mode;
    if (!mode) return;
    wx.setStorageSync('displayMode', mode);
    this.updateOptionsAndApply();
  },

  onLangTap(event) {
    const lang = event.currentTarget.dataset.lang;
    if (!lang) return;
    setLanguage(lang);
    this.updateOptionsAndApply();
  },

  onLayoutTap(event) {
    const layout = event.currentTarget.dataset.layout;
    if (!layout) return;
    wx.setStorageSync('treeholePostLayout', layout);
    this.updateOptionsAndApply();
  }
});
