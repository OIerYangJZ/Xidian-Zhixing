import request from '../utils/request';
import { getData } from '../utils/format';

export const getCurrentUser = async () => {
  const cached = wx.getStorageSync('userInfo');
  if (cached && cached.id) return cached;
  const response = await request.get('/api/users/me');
  const user = getData(response, {});
  wx.setStorageSync('userInfo', user);
  return user;
};

export const getCurrentUserId = async () => {
  const user = await getCurrentUser();
  const id = String(user.id || '').trim();
  if (!id) throw new Error('当前登录账号缺少用户 ID');
  return id;
};

export const clearCurrentUser = () => wx.removeStorageSync('userInfo');
