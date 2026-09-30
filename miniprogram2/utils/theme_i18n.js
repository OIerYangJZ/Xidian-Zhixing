import { getTranslation, getLanguage } from './i18n';

export const getDisplayTheme = () => 'reference';
export const getDisplayMode = () => wx.getStorageSync('displayMode') || 'system';
export const resolveDisplayMode = (mode) => mode === 'system' ? (wx.getAppBaseInfo().theme || 'light') : mode;

export const applyThemeAndLanguage = (page) => {
  const displayMode = getDisplayMode();
  const resolvedDisplayMode = resolveDisplayMode(displayMode);
  const lang = getLanguage();
  const themeClass = `theme-reference color-mode-${resolvedDisplayMode} ${lang === 'en' ? 'lang-en' : 'lang-zh'}`;
  const update = {
    themeClass, currentTheme: 'reference', currentDisplayMode: displayMode,
    resolvedDisplayMode, currentLanguage: lang
  };
  if (page.data.currentLanguage !== lang || !page.data.t) update.t = getTranslation(lang);
  Object.keys(update).forEach(key => { if (page.data[key] === update[key]) delete update[key]; });
  if (Object.keys(update).length) page.setData(update);
  const dark = resolvedDisplayMode === 'dark';
  const backgroundColor = dark ? '#000000' : '#ffffff';
  wx.setNavigationBarColor({ frontColor: dark ? '#ffffff' : '#000000', backgroundColor });
  wx.setBackgroundColor({ backgroundColor, backgroundColorTop: backgroundColor, backgroundColorBottom: backgroundColor });
  if (typeof page.getTabBar === 'function' && page.getTabBar()) {
    page.getTabBar().sync();
  }
};
