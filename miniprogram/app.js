App({
  globalData: {
    appName: '电台',
    clientType: 'wechat-miniprogram'
  },

  onLaunch() {
    const token = wx.getStorageSync('token');
    this.globalData.hasToken = Boolean(token);
  }
});
