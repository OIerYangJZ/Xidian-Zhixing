const TAB_ROUTES = ["/pages/treehole/index","/pages/campus/search/index","/pages/ai/index","/pages/profile/notifications/index","/pages/profile/conversations/index"];
export const openAppTarget = (target = {}) => {
  const path = String(target.path || target.jumpUrl || '').trim();
  const url = String(target.url || target.originalUrl || '').trim();
  if (/^\/?pages\//.test(path)) {
    const route = path.startsWith('/') ? path : '/' + path;
    const routePath = route.split('?')[0];
    if (TAB_ROUTES.includes(routePath)) {
      if (routePath === '/pages/campus/search/index' && route.includes('?')) {
        const keyword = route.match(/[?&]keyword=([^&]*)/);
        wx.switchTab({ url: routePath, success() {
          if (!keyword) return;
          const pages = getCurrentPages();
          const page = pages[pages.length - 1];
          page.setData({ keyword: decodeURIComponent(keyword[1]), activeType: 'posts' });
          page.search();
        } });
      } else wx.switchTab({ url: routePath });
    } else wx.navigateTo({ url: route });
    return true;
  }
  if (url) {
    wx.navigateTo({ url: `/pages/campus/webview/index?url=${encodeURIComponent(url)}` });
    return true;
  }
  return false;
};
