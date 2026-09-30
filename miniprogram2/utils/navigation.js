const TAB_ROUTES = ["/pages/treehole/index","/pages/campus/index","/pages/ai/index","/pages/profile/conversations/index","/pages/profile/index"];
export const openAppTarget = (target = {}) => {
  const path = String(target.path || target.jumpUrl || '').trim();
  const url = String(target.url || target.originalUrl || '').trim();
  if (/^\/?pages\//.test(path)) {
    const route = path.startsWith('/') ? path : '/' + path;
    const routePath = route.split('?')[0];
    if (TAB_ROUTES.includes(routePath)) {
      wx.switchTab({ url: routePath });
    } else wx.navigateTo({ url: route });
    return true;
  }
  if (url) {
    wx.navigateTo({ url: `/pages/campus/webview/index?url=${encodeURIComponent(url)}` });
    return true;
  }
  return false;
};
