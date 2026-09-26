import { clearCampusAuthSession } from './campus_auth';
import { isTabRoute } from './navigation';

const LOGIN_PAGE = '/pages/profile/auth/index';
const APPEAL_PAGE = '/pages/profile/appeal/index';

let isNavigating = false;

const withNavLock = (fn) => {
  if (isNavigating) return;
  isNavigating = true;
  fn();
  setTimeout(() => {
    isNavigating = false;
  }, 1000);
};

const isLoginRoute = () => {
  const pages = getCurrentPages();
  const current = pages[pages.length - 1];
  if (!current) return false;
  const route = `/${current.route || ''}`;
  return route === LOGIN_PAGE;
};

// Full URL of the current page, so the login page can come back to it.
const currentPageUrl = () => {
  const pages = getCurrentPages();
  const current = pages[pages.length - 1];
  if (!current) return '';
  const query = Object.keys(current.options || {})
    .map((key) => `${key}=${encodeURIComponent(current.options[key])}`)
    .join('&');
  return `/${current.route || ''}${query ? `?${query}` : ''}`;
};

const isCurrentPageTabbar = () => {
  const pages = getCurrentPages();
  const current = pages[pages.length - 1];
  if (!current) return false;
  const route = `/${current.route || ''}`;
  return isTabRoute(route);
};

export const hasLogin = () => {
  return Boolean(wx.getStorageSync('token'));
};

export const clearLocalSession = () => {
  wx.removeStorageSync('token');
  clearCampusAuthSession();
};

export const requireLoginPage = () => {
  if (hasLogin()) return true;
  if (!isLoginRoute()) {
    withNavLock(() => {
      if (isCurrentPageTabbar()) {
        wx.navigateTo({ url: LOGIN_PAGE });
      } else {
        // redirectTo replaces this page, so navigateBack after login would
        // skip it (or find nothing, when it was opened from a share card or
        // a scanned link). Hand its URL to the login page instead.
        const redirect = currentPageUrl();
        wx.redirectTo({
          url: redirect ? `${LOGIN_PAGE}?redirect=${encodeURIComponent(redirect)}` : LOGIN_PAGE
        });
      }
    });
  }
  return false;
};

// A banned session reaches only its profile and the appeal endpoints, so every
// other page would be a screen of refused requests.
export const redirectToAppeal = () => {
  const pages = getCurrentPages();
  const current = pages[pages.length - 1];
  if (current && `/${current.route || ''}` === APPEAL_PAGE) return;
  withNavLock(() => {
    wx.reLaunch({ url: APPEAL_PAGE });
  });
};

export const clearLoginAndRedirect = () => {
  clearLocalSession();
  if (!isLoginRoute()) {
    withNavLock(() => {
      wx.reLaunch({ url: LOGIN_PAGE });
    });
  }
};
