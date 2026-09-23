// Must match tabBar.list in app.json. navigateTo/redirectTo fail on a tab
// page, so every caller that routes to an arbitrary path checks this first.
export const TAB_ROUTES = [
  '/pages/treehole/index',
  '/pages/campus/index',
  '/pages/ai/index'
];

export const isTabRoute = (route) => TAB_ROUTES.includes(String(route || '').split('?')[0]);

export const openAppTarget = (target = {}) => {
  const path = String(target.path || target.jumpUrl || '').trim();
  const url = String(target.url || target.originalUrl || '').trim();

  if (/^\/?pages\//.test(path)) {
    const route = path.startsWith('/') ? path : `/${path}`;
    if (isTabRoute(route)) {
      // switchTab drops the query string; tab pages take no parameters.
      wx.switchTab({ url: route.split('?')[0] });
    } else {
      wx.navigateTo({ url: route });
    }
    return true;
  }

  if (url) {
    wx.navigateTo({ url: `/pages/campus/webview/index?url=${encodeURIComponent(url)}` });
    return true;
  }

  return false;
};
