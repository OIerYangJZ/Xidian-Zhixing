import request from '../utils/request';
import {
  getData,
  resolveUrl,
  responseContractError
} from '../utils/format';

const requireSessionData = (response) => {
  const data = getData(response, {});
  const attemptId = String(data.attemptId || '').trim();
  const status = String(data.status || '').trim();
  const platform = String(data.platform || '').trim();
  if (!attemptId || !['pending', 'authenticated', 'failed'].includes(status) || !platform) {
    throw responseContractError('统一认证会话响应格式无效');
  }
  if (status !== 'authenticated') return response;
  const token = String(data.token || '').trim();
  const studentId = String(data.studentId || '').trim();
  if (token && studentId && data.verified === true) {
    return response;
  }
  // A result is handed out once; polling again gets 登录结果已使用，请重新发起登录.
  if (!token && String(data.message || '').trim()) {
    throw responseContractError(String(data.message).trim());
  }
  throw responseContractError('统一认证响应缺少有效登录凭据');
};

const normalizeUser = (user = {}) => {
  return {
    ...user,
    // PATCH /api/users/me only accepts the relative storage path.
    backgroundImagePath: user.backgroundImageUrl || '',
    avatarUrl: resolveUrl(user.avatarUrl || ''),
    backgroundImageUrl: resolveUrl(user.backgroundImageUrl || '')
  };
};

/**
 * 创建西电官方统一身份认证会话。
 */
export const createXidianAuthSession = async () => {
  const response = await request.post('/api/auth/xidian/session', {
    platform: 'mobile',
    nextPath: '/'
  });
  const data = getData(requireSessionData(response), {});
  if (!String(data.authorizeUrl || '').trim()) {
    throw responseContractError('统一认证会话缺少官方授权地址');
  }
  return response;
};

export const fetchXidianAuthSession = async (attemptId) => {
  const encoded = encodeURIComponent(String(attemptId || '').trim());
  const response = await request.get(`/api/auth/xidian/session/${encoded}`);
  return requireSessionData(response);
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
 * 退出登录
 */
export const logout = () => {
  return request.post('/api/auth/logout');
};
