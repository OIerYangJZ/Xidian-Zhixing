import request from '../utils/request';
import {
  getData,
  resolveUrl,
  responseContractError
} from '../utils/format';

const requireAuthData = (response, { allowNeedVerify = false } = {}) => {
  const data = getData(response, {});
  const token = String(data.token || data.accessToken || '').trim();
  if (token) {
    return response;
  }
  if (allowNeedVerify && data.needVerify === true) {
    return response;
  }
  throw responseContractError('认证响应缺少登录凭据');
};

const normalizeUser = (user = {}) => {
  return {
    ...user,
    avatarUrl: resolveUrl(user.avatarUrl || ''),
    backgroundImageUrl: resolveUrl(user.backgroundImageUrl || '')
  };
};

/**
 * 账号密码登录
 * @param {string} identifier - 学号或邮箱
 * @param {string} password - 密码
 */
export const login = async (identifier, password) => {
  const response = await request.post('/api/auth/login', { identifier, password });
  return requireAuthData(response, { allowNeedVerify: true });
};

/**
 * 创建西电统一认证会话
 */
export const createXidianAuthSession = (platform = 'mobile', nextPath = '/') => {
  return request.post('/api/auth/xidian/session', { platform, nextPath });
};

/**
 * 轮询西电统一认证会话
 */
export const getXidianAuthSession = (attemptId) => {
  return request.get(`/api/auth/xidian/session/${attemptId}`);
};

/**
 * 注册
 */
export const register = (data) => {
  return request.post('/api/auth/register', data);
};

/**
 * 邮箱验证码验证
 */
export const verifyEmail = async (email, code, password = '') => {
  const response = await request.post('/api/auth/verify', { email, code, password });
  return requireAuthData(response);
};

/**
 * 获取当前用户信息（包含认证状态）
 */
export const getUserInfo = async () => {
  const response = await request.get('/api/users/me');
  return {
    ...response,
    data: normalizeUser(getData(response, {}))
  };
};

/**
 * 发送验证码
 */
export const sendCode = (email) => {
  return request.post('/api/auth/send-code', { email });
};

export const sendPasswordResetCode = (email) => {
  return request.post('/api/auth/password/send-code', { email });
};

export const resetPassword = (email, code, newPassword) => {
  return request.post('/api/auth/password/reset', { email, code, newPassword });
};

/**
 * 退出登录
 */
export const logout = () => {
  return request.post('/api/auth/logout');
};
