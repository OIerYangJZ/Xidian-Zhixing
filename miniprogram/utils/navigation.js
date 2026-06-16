export const openAppTarget = (target = {}) => {
  const path = String(target.path || target.jumpUrl || '').trim();
  const url = String(target.url || target.originalUrl || '').trim();

  if (path) {
    if (/^\/pages\//.test(path)) {
      wx.navigateTo({ url: path });
      return true;
    }
    if (/^\/?pages\//.test(path)) {
      wx.navigateTo({ url: path.startsWith('/') ? path : `/${path}` });
      return true;
    }
  }

  if (url) {
    wx.navigateTo({ url: `/pages/campus/webview/index?url=${encodeURIComponent(url)}` });
    return true;
  }

  return false;
};
