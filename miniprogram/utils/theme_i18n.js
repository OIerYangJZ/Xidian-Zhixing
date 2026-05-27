import { getTranslation, getLanguage } from './i18n';

const THEME_MAP = {
  zhushachi: { navBg: '#FAF4EA', navFront: '#000000', tabSelectedColor: '#B23A2E' },
  yanzhihong: { navBg: '#FBF1F3', navFront: '#000000', tabSelectedColor: '#B8324A' },
  chitaonuan: { navBg: '#FBF3EA', navFront: '#000000', tabSelectedColor: '#B85B3E' },
  zaonihong: { navBg: '#F9F1EA', navFront: '#000000', tabSelectedColor: '#8F2F2C' },
  xuanzhizhu: { navBg: '#FFF8EE', navFront: '#000000', tabSelectedColor: '#C43A2F' },
  zhuqing: { navBg: '#F3F8F1', navFront: '#000000', tabSelectedColor: '#4F8A5F' },
  ouhezi: { navBg: '#F8F4FA', navFront: '#000000', tabSelectedColor: '#8B6F9E' },
  xingrenhuang: { navBg: '#FCF7EC', navFront: '#000000', tabSelectedColor: '#C28A3A' },
  haiyanqing: { navBg: '#F1F8F8', navFront: '#000000', tabSelectedColor: '#5B9EA6' },
  mohui: { navBg: '#F5F4F0', navFront: '#000000', tabSelectedColor: '#4F5552' }
};

export const getDisplayTheme = () => {
  return wx.getStorageSync('colorTheme') || 'zhushachi';
};

export const applyThemeAndLanguage = (page) => {
  const theme = getDisplayTheme();
  const lang = getLanguage();
  const t = getTranslation(lang);
  const themeClass = 'theme-' + theme;
  const colors = THEME_MAP[theme];
  page.setData({
    themeClass,
    currentTheme: theme,
    currentLanguage: lang,
    t
  });
  wx.setNavigationBarColor({
    frontColor: colors.navFront,
    backgroundColor: colors.navBg,
    animation: { duration: 100 }
  });
  wx.setTabBarStyle({
    color: '#8E8E93',
    selectedColor: colors.tabSelectedColor,
    backgroundColor: '#ffffff',
    borderStyle: 'white'
  });
};
