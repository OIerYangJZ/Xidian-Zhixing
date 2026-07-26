import { clearLegacyCampusAuthSecrets } from './utils/campus_auth';

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
