// The administrator session, kept apart from the student one.
//
// Administrator accounts are their own accounts (username + password, POST
// /api/admin/auth/login), not student accounts with a flag.  Their token is
// stored under its own key, so signing in or out as an administrator never
// touches the student session, and someone without a student account
// (school staff) can still use the console.
export const ADMIN_LOGIN_PAGE = '/pages/admin/login/index';
export const ADMIN_CONSOLE_PAGE = '/pages/admin/index';

const TOKEN_KEY = 'adminToken';
const INFO_KEY = 'adminInfo';

export const getAdminToken = () => wx.getStorageSync(TOKEN_KEY) || '';

export const getAdminInfo = () => wx.getStorageSync(INFO_KEY) || null;

export const setAdminSession = (token, info) => {
  wx.setStorageSync(TOKEN_KEY, token);
  wx.setStorageSync(INFO_KEY, info || null);
};

export const clearAdminSession = () => {
  wx.removeStorageSync(TOKEN_KEY);
  wx.removeStorageSync(INFO_KEY);
};

// The console if signed in as an administrator, else its login page.
export const openAdminConsole = () => {
  wx.navigateTo({ url: getAdminToken() ? ADMIN_CONSOLE_PAGE : ADMIN_LOGIN_PAGE });
};

let redirecting = false;
export const redirectToAdminLogin = () => {
  if (redirecting) return;
  redirecting = true;
  wx.redirectTo({
    url: ADMIN_LOGIN_PAGE,
    complete: () => setTimeout(() => { redirecting = false; }, 1000)
  });
};
