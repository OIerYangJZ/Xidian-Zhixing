import { getTranslation, getLanguage } from './i18n';

const THEME_MAP = {
  zhushachi: {
    navBg: '#F7F6F2',
    navFront: '#000000',
    tabBg: '#FFFEFA',
    tabSelectedColor: '#A43B32',
    tabSelectedColorDark: '#E08075'
  },
  zhuqing: {
    navBg: '#F3F7F2',
    navFront: '#000000',
    tabBg: '#FFFEF9',
    tabSelectedColor: '#426F52',
    tabSelectedColorDark: '#91C29C'
  },
  xingrenhuang: {
    navBg: '#FBF6EA',
    navFront: '#000000',
    tabBg: '#FFFEF8',
    tabSelectedColor: '#94631F',
    tabSelectedColorDark: '#E1B665'
  }
};

const TAB_BAR_ITEMS = [
  { index: 0, key: 'home' },
  { index: 1, key: 'campus' },
  { index: 2, key: 'ai' }
];

export const getDisplayTheme = () => {
  const stored = wx.getStorageSync('colorTheme');
  const resolved = (() => {
    switch (stored) {
      case '':
      case undefined:
      case null:
        return 'zhushachi';
      case 'zhushachi':
      case 'zhuqing':
      case 'xingrenhuang':
        return stored;
      case 'haiyanqing':
        return 'zhuqing';
      case 'minimal':
      case 'yanzhihong':
      case 'chitaonuan':
      case 'zaonihong':
      case 'xuanzhizhu':
      case 'ouhezi':
      case 'mohui':
        return 'zhushachi';
      default:
        throw new Error(`Unknown stored color theme: ${stored}`);
    }
  })();
  if (stored && stored !== resolved) {
    wx.setStorageSync('colorTheme', resolved);
  }
  return resolved;
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
  const languageClass = lang === 'en' ? 'lang-en' : 'lang-zh';
  const themeClass = `theme-${theme} color-mode-${resolvedDisplayMode} ${languageClass}`;
  const colors = THEME_MAP[theme];
  const isDark = resolvedDisplayMode === 'dark';
  const navBg = isDark ? '#000000' : colors.navBg;
  const navFront = isDark ? '#ffffff' : colors.navFront;
  const tabBg = isDark ? '#000000' : colors.tabBg;
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
      text: t[item.key],
      selectedIconPath: `assets/tabbar/theme-${theme}${isDark ? '_dark' : ''}/${item.key}_selected.png`
    });
  });
};
