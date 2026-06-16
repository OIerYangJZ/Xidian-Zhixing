import { getTranslation, getLanguage } from './i18n';

const THEME_MAP = {
  zhushachi: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#A8332C', tabSelectedColorDark: '#ffffff' },
  yanzhihong: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#A8332C', tabSelectedColorDark: '#ffffff' },
  chitaonuan: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#A8332C', tabSelectedColorDark: '#ffffff' },
  zaonihong: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#A8332C', tabSelectedColorDark: '#ffffff' },
  xuanzhizhu: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#A8332C', tabSelectedColorDark: '#ffffff' },
  zhuqing: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#A8332C', tabSelectedColorDark: '#ffffff' },
  ouhezi: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#A8332C', tabSelectedColorDark: '#ffffff' },
  xingrenhuang: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#A8332C', tabSelectedColorDark: '#ffffff' },
  haiyanqing: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#A8332C', tabSelectedColorDark: '#ffffff' },
  mohui: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#A8332C', tabSelectedColorDark: '#ffffff' },
  minimal: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#A8332C', tabSelectedColorDark: '#ffffff' }
};

const TAB_BAR_ITEMS = [
  { index: 0, key: 'home' },
  { index: 1, key: 'campus' },
  { index: 2, key: 'ai' },
  { index: 3, key: 'announcements' }
];

export const getDisplayTheme = () => {
  return wx.getStorageSync('colorTheme') || 'minimal';
};

export const getDisplayMode = () => {
  return wx.getStorageSync('displayMode') || 'system';
};

export const resolveDisplayMode = (mode) => {
  if (mode === 'system') {
    const appBaseInfo = wx.getAppBaseInfo ? wx.getAppBaseInfo() : {};
    return appBaseInfo.theme || 'light';
  }
  return mode;
};

export const applyThemeAndLanguage = (page) => {
  const theme = getDisplayTheme();
  const displayMode = getDisplayMode();
  const resolvedDisplayMode = resolveDisplayMode(displayMode);
  const lang = getLanguage();
  const t = getTranslation(lang);
  const themeClass = `theme-${theme} color-mode-${resolvedDisplayMode}`;
  const colors = THEME_MAP[theme];
  const isDark = resolvedDisplayMode === 'dark';
  const navBg = isDark ? '#000000' : colors.navBg;
  const navFront = isDark ? '#ffffff' : colors.navFront;
  const tabBg = isDark ? '#000000' : '#ffffff';
  const tabColor = isDark ? '#ffffff' : '#8E8E93';
  page.setData({
    themeClass,
    currentTheme: theme,
    currentDisplayMode: displayMode,
    resolvedDisplayMode,
    currentLanguage: lang,
    t
  });
  wx.setNavigationBarColor({
    frontColor: navFront,
    backgroundColor: navBg,
    animation: { duration: 100 }
  });
  wx.setTabBarStyle({
    color: tabColor,
    selectedColor: isDark ? colors.tabSelectedColorDark : colors.tabSelectedColor,
    backgroundColor: tabBg,
    borderStyle: isDark ? 'black' : 'white'
  });
  TAB_BAR_ITEMS.forEach((item) => {
    wx.setTabBarItem({
      index: item.index,
      selectedIconPath: `assets/tabbar/theme-${theme}${isDark ? '_dark' : ''}/${item.key}_selected.png`
    });
  });
};
