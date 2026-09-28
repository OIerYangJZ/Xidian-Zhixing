import { baseUrl, envName } from '../config/env';
import { clearLoginAndRedirect, redirectToAppeal } from './auth_guard';
import { clearAdminSession, getAdminToken, redirectToAdminLogin } from './admin_session';

// 防止多个并发请求失败时弹出多个 Toast
let _lastToastTime = 0;
const showToastOnce = (title, icon = 'none') => {
  const now = Date.now();
  if (now - _lastToastTime < 2000) return;
  _lastToastTime = now;
  wx.showToast({ title, icon });
};

const buildUrl = (url) => {
  if (url.startsWith('http')) return url;
  return `${baseUrl.replace(/\/$/, '')}${url}`;
};

const networkErrorMessage = () => {
  if (/localhost|127\.0\.0\.1/i.test(baseUrl)) {
    return '真机无法访问 localhost，请改用电脑局域网 IP';
  }
  if (envName === 'lan' || envName === 'auto:lan') {
    return '请确认手机和电脑在同一 Wi-Fi，且电脑防火墙允许 8080 端口';
  }
  return '网络异常，请检查域名和 HTTPS 配置';
};

const requestFailMessage = (err, elapsedMs, timeoutMs) => {
  const errMsg = String((err && err.errMsg) || err || '');
  const isTimeout = /timeout/i.test(errMsg);
  if (isTimeout && elapsedMs >= Math.max(1000, timeoutMs - 1000)) {
    return '请求超时，请稍后重试';
  }
  if (isTimeout) {
    return networkErrorMessage();
  }
  return networkErrorMessage();
};

/**
 * 封装微信的 wx.request
 *
 * options.admin: an administrator request, carrying the administrator token
 * (utils/admin_session) instead of the student one; a 401 then ends the
 * administrator session only.  options.anonymous: no token at all (the
 * administrator login itself).
 */
const request = (options) => {
  return new Promise((resolve, reject) => {
    const isAdmin = Boolean(options.admin);
    const requestUrl = options.url || '';
    const isPublicAuthPath = Boolean(options.anonymous)
      || requestUrl === '/api/auth/xidian/session'
      || requestUrl.startsWith('/api/auth/xidian/session/');
    const token = isPublicAuthPath ? '' : (isAdmin ? getAdminToken() : wx.getStorageSync('token'));

    if (!token && !isPublicAuthPath) {
      if (isAdmin) redirectToAdminLogin();
      else clearLoginAndRedirect();
      reject({ statusCode: 401, data: { message: isAdmin ? '请先登录管理员账号' : '请先登录' } });
      return;
    }

    // 默认 header
    const header = {
      'Content-Type': 'application/json',
      'X-Client-Type': 'wechat-miniprogram', // 标识来源，方便后端识别
      ...options.header
    };

    if (token && !isPublicAuthPath) {
      header['Authorization'] = `Bearer ${token}`;
    }

    const url = buildUrl(options.url);
    const timeoutMs = options.timeout || 15000;
    const startedAt = Date.now();

    wx.request({
      url,
      method: options.method || 'GET',
      data: options.data || {},
      header: header,
      timeout: timeoutMs,
      success: (res) => {
        const { statusCode, data } = res;
        
        // HTTP 状态码 2xx 表示成功
        if (statusCode >= 200 && statusCode < 300) {
          resolve(data);
        } else if (statusCode === 401 && isAdmin && token) {
          // The administrator session ended (expired, signed out elsewhere,
          // server restarted); the student session is left alone.
          clearAdminSession();
          wx.showToast({ title: '管理员登录已失效，请重新登录', icon: 'none' });
          redirectToAdminLogin();
          reject(res);
        } else if (
          !isAdmin
          && 
          statusCode === 401
          && token
          && (!options.keepSessionOnUnauthorized || (data && data.message === '请先登录'))
        ) {
          // 未登录或 token 过期
          clearLoginAndRedirect();
          wx.showToast({
            title: '登录已过期，请重新登录',
            icon: 'none'
          });
          reject(res);
        } else if (
          !isAdmin
          && statusCode === 403
          && token
          && data && data.data && data.data.accountState === 'banned'
        ) {
          // 账号已被封禁: the appeal page explains; no toast on top of it.
          redirectToAppeal();
          reject(res);
        } else {
          // 其他服务器错误
          console.error('[request http error]', url, res);
          if (!options.silentErrorToast) {
            showToastOnce((data && data.message) || networkErrorMessage());
          }
          reject(res);
        }
      },
      fail: (err) => {
        console.error('[request failed]', url, err);
        const message = requestFailMessage(err, Date.now() - startedAt, timeoutMs);
        if (!options.silentErrorToast) {
          showToastOnce(message);
        }
        reject(err);
      }
    });
  });
};

// 提供快捷方法
request.get = (url, data, options = {}) => {
  return request({ url, method: 'GET', data, ...options });
};

request.post = (url, data, options = {}) => {
  return request({ url, method: 'POST', data, ...options });
};

request.put = (url, data, options = {}) => {
  return request({ url, method: 'PUT', data, ...options });
};

request.delete = (url, data, options = {}) => {
  return request({ url, method: 'DELETE', data, ...options });
};

request.patch = (url, data, options = {}) => {
  return request({ url, method: 'PATCH', data, ...options });
};

export default request;
