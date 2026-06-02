import { getTranslation, getLanguage } from './i18n';

const THEME_MAP = {
  zhushachi: { navBg: '#FAF4EA', navFront: '#000000', tabSelectedColor: '#B23A2E', tabSelectedColorDark: '#D94A38' },
  yanzhihong: { navBg: '#FBF1F3', navFront: '#000000', tabSelectedColor: '#B8324A', tabSelectedColorDark: '#D94F68' },
  chitaonuan: { navBg: '#FBF3EA', navFront: '#000000', tabSelectedColor: '#B85B3E', tabSelectedColorDark: '#D97855' },
  zaonihong: { navBg: '#F9F1EA', navFront: '#000000', tabSelectedColor: '#8F2F2C', tabSelectedColorDark: '#B54A43' },
  xuanzhizhu: { navBg: '#FFF8EE', navFront: '#000000', tabSelectedColor: '#C43A2F', tabSelectedColorDark: '#E15A48' },
  zhuqing: { navBg: '#F3F8F1', navFront: '#000000', tabSelectedColor: '#4F8A5F', tabSelectedColorDark: '#78B985' },
  ouhezi: { navBg: '#F8F4FA', navFront: '#000000', tabSelectedColor: '#8B6F9E', tabSelectedColorDark: '#AD93BF' },
  xingrenhuang: { navBg: '#FCF7EC', navFront: '#000000', tabSelectedColor: '#C28A3A', tabSelectedColorDark: '#DDAA5C' },
  haiyanqing: { navBg: '#F1F8F8', navFront: '#000000', tabSelectedColor: '#5B9EA6', tabSelectedColorDark: '#84C2C8' },
  mohui: { navBg: '#F5F4F0', navFront: '#000000', tabSelectedColor: '#4F5552', tabSelectedColorDark: '#747D78' },
  minimal: { navBg: '#ffffff', navFront: '#000000', tabSelectedColor: '#000000', tabSelectedColorDark: '#ffffff' }
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
  if (mode === 'system') return wx.getSystemInfoSync().theme;
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
