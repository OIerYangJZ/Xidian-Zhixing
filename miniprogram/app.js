import { clearLegacyCampusAuthSecrets } from './utils/campus_auth';
import { applyThemeAndLanguage, getDisplayMode } from './utils/theme_i18n';

App({
  globalData: {
    appName: '西电知行',
    clientType: 'wechat-miniprogram',
    navTop: 44,
    navHeight: 32
  },

  onLaunch() {
    const token = wx.getStorageSync('token');
    this.globalData.hasToken = Boolean(token);
    clearLegacyCampusAuthSecrets();
    this.initSystemInfo();
    // 跟随系统: switching the phone between light and dark repaints the
    // page on screen (the others repaint in their own onShow).
    if (wx.onThemeChange) {
      wx.onThemeChange(() => {
        if (getDisplayMode() !== 'system') return;
        const pages = getCurrentPages();
        const current = pages[pages.length - 1];
        if (current) applyThemeAndLanguage(current);
      });
    }
  },

  initSystemInfo() {
    const windowInfo = wx.getWindowInfo ? wx.getWindowInfo() : {};
    const statusBarHeight = windowInfo.statusBarHeight || 20;
    
    let menuButton = null;
    try {
      menuButton = wx.getMenuButtonBoundingClientRect();
    } catch (e) {
      // ignore
    }

    let navTop = statusBarHeight;
    let navHeight = 44;
    
    if (menuButton && menuButton.top && menuButton.height) {
      navTop = menuButton.top;
      navHeight = menuButton.height;
    } else {
      navTop = statusBarHeight + 6;
      navHeight = 32;
    }

    if (navTop <= 0) {
      navTop = 20;
    }
    if (navHeight <= 0) {
      navHeight = 44;
    }

    this.globalData.navTop = navTop;
    this.globalData.navHeight = navHeight;
    this.globalData.statusBarHeight = statusBarHeight;
  }
});
