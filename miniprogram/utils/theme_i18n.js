import { getTranslation, getLanguage } from './i18n';

export const getDisplayTheme = () => 'reference';
export const getDisplayMode = () => wx.getStorageSync('displayMode') || 'system';
export const resolveDisplayMode = (mode) => mode === 'system' ? (wx.getAppBaseInfo().theme || 'light') : mode;

export const applyThemeAndLanguage = (page) => {
  const displayMode = getDisplayMode();
  const resolvedDisplayMode = resolveDisplayMode(displayMode);
  const lang = getLanguage();
  const themeClass = `theme-reference color-mode-${resolvedDisplayMode} ${lang === 'en' ? 'lang-en' : 'lang-zh'}`;
  page.setData({
    themeClass, currentTheme: 'reference', currentDisplayMode: displayMode,
    resolvedDisplayMode, currentLanguage: lang, t: getTranslation(lang)
  });
  const dark = resolvedDisplayMode === 'dark';
  const backgroundColor = dark ? '#101010' : '#ffffff';
  wx.setNavigationBarColor({ frontColor: dark ? '#ffffff' : '#000000', backgroundColor });
  wx.setBackgroundColor({ backgroundColor, backgroundColorTop: backgroundColor, backgroundColorBottom: backgroundColor });
  if (typeof page.getTabBar === 'function' && page.getTabBar()) {
    page.getTabBar().sync();
  }
};
