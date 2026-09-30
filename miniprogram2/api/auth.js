import request from '../utils/request';
import { getData, resolveUrl } from '../utils/format';
import { clearCurrentUser } from './session';

const normalizeUser = (user = {}) => {
  return {
    ...user,
    nickname: user.nickname || user.name || '',
    avatarUrl: resolveUrl(user.avatarUrl || user.profilePhoto || ''),
    backgroundImageUrl: resolveUrl(user.backgroundImageUrl || user.coverPhoto || '')
  };
};

/**
 * 创建西电官方统一身份认证会话。
 */
export const createXidianAuthSession = async () => {
  const response = await request.post('/api/auth/xidian/session', {
    callbackUrl: '/miniprogram-auth'
  });
  const data = getData(response, {});
  if (!String(data.authorizeUrl || '').trim()) {
    throw new Error('统一认证会话缺少官方授权地址');
  }
  return response;
};

export const createLocalTestSession = async () => {
  const response = await request.post('/api/auth/local-test', {});
  const data = getData(response, {});
  if (!String(data.token || '').trim() || !data.user || !String(data.user.id || '').trim()) {
    throw new Error('本地测试登录响应无效');
  }
  return response;
};

export const fetchXidianAuthSession = async (attemptId) => {
  const encoded = encodeURIComponent(String(attemptId || '').trim());
  const response = await request.get(`/api/auth/xidian/session/${encoded}`);
  const session = getData(response, {});
  if (session.status !== 'approved') {
    return {
      ...response,
      data: { ...session, status: session.status === 'expired' || session.status === 'consumed' ? 'failed' : session.status }
    };
  }

  const tokenResponse = await request.post(`/api/auth/xidian/session/${encoded}/token`, {});
  const tokenData = getData(tokenResponse, {});
  return { ...tokenResponse, data: { ...tokenData, status: 'authenticated', verified: true } };
};

/**
 * 获取当前用户信息（包含认证状态）
 */
export const getUserInfo = async () => {
  const response = await request.get('/api/users/me');
  const user = normalizeUser(getData(response, {}));
  wx.setStorageSync('userInfo', user);
  return {
    ...response,
    data: user
  };
};

/**
 * 退出登录
 */
export const logout = async () => {
  wx.removeStorageSync('token');
  clearCurrentUser();
  getApp().globalData.hasToken = false;
  return { data: { loggedOut: true } };
};
