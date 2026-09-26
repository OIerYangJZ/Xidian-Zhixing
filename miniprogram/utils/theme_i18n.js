import { getTranslation, getLanguage } from './i18n';

// Nav and tab bar colours per theme, light and dark, from the design
// tokens (styles/zx-tokens.wxss): bg, surface, text-3 and primary.
const THEME_MAP = {
  zhushachi: {
    light: { bg: '#F7F6F2', surface: '#FFFEFA', idle: '#5D5D5A', selected: '#A43B32' },
    dark: { bg: '#171714', surface: '#20201C', idle: '#9F9D96', selected: '#E08075' }
  },
  zhuqing: {
    light: { bg: '#F3F7F2', surface: '#FFFEF9', idle: '#636A63', selected: '#426F52' },
    dark: { bg: '#151A16', surface: '#1D241F', idle: '#9CA19B', selected: '#91C29C' }
  },
  xingrenhuang: {
    light: { bg: '#FBF6EA', surface: '#FFFEF8', idle: '#6E685F', selected: '#94631F' },
    dark: { bg: '#1B1812', surface: '#252118', idle: '#A29D92', selected: '#E1B665' }
  },
  mozhuxinye: {
    light: { bg: '#FFFFFF', surface: '#FFFFFF', idle: '#5E5E5D', selected: '#AB3E36' },
    dark: { bg: '#151513', surface: '#1D1D1B', idle: '#9F9F9B', selected: '#E37D73' }
  }
};

// The five tabs, in app.json order; icon files are assets/tabbar/<theme>[_dark]/<icon>[-active].png.
export const TAB_BAR_ITEMS = [
  { index: 0, key: 'home', icon: 'treehole' },
  { index: 1, key: 'campus', icon: 'campus' },
  { index: 2, key: 'ai', icon: 'ai' },
  { index: 3, key: 'tab_messages', icon: 'message' },
  { index: 4, key: 'tab_mine', icon: 'mine' }
];

export const MESSAGES_TAB_INDEX = 3;

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
      case 'mozhuxinye':
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
  const isDark = resolvedDisplayMode === 'dark';
  const colors = THEME_MAP[theme][isDark ? 'dark' : 'light'];
  page.setData({
    themeClass,
    currentTheme: theme,
    currentDisplayMode: displayMode,
    resolvedDisplayMode,
    currentLanguage: lang,
    // Native components (switch) take a colour, not a CSS variable.
    themePrimary: colors.selected,
    t
  });
  wx.setNavigationBarColor({
    frontColor: isDark ? '#ffffff' : '#000000',
    backgroundColor: colors.bg,
    animation: { duration: 100 }
  });
  // Only tab pages have a tab bar; elsewhere these calls fail quietly.
  const quiet = { fail() {} };
  wx.setTabBarStyle({
    color: colors.idle,
    selectedColor: colors.selected,
    backgroundColor: colors.surface,
    borderStyle: isDark ? 'black' : 'white',
    ...quiet
  });
  const iconDir = `assets/tabbar/${theme}${isDark ? '_dark' : ''}`;
  TAB_BAR_ITEMS.forEach((item) => {
    wx.setTabBarItem({
      index: item.index,
      text: t[item.key],
      iconPath: `${iconDir}/${item.icon}.png`,
      selectedIconPath: `${iconDir}/${item.icon}-active.png`,
      ...quiet
    });
  });
};

/** Unread count on the 消息 tab; zero clears it. */
export const setMessagesTabBadge = (count) => {
  const quiet = { fail() {} };
  const n = Number(count) || 0;
  if (n > 0) {
    wx.setTabBarBadge({ index: MESSAGES_TAB_INDEX, text: n > 99 ? '99+' : String(n), ...quiet });
  } else {
    wx.removeTabBarBadge({ index: MESSAGES_TAB_INDEX, ...quiet });
  }
};
