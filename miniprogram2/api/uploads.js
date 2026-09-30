import request from '../utils/request';
import { baseUrl } from '../config/env';
import { getCurrentUserId } from './session';

const uploadProfileMedia = async (filePath, kind) => {
  const userId = await getCurrentUserId();
  const token = wx.getStorageSync('token');
  const endpoint = kind === 'avatar' ? 'profile-photo' : 'cover-photo';
  const response = await new Promise((resolve, reject) => wx.uploadFile({
    url: `${baseUrl.replace(/\/$/, '')}/api/users/${encodeURIComponent(userId)}/${endpoint}`,
    filePath,
    name: 'file',
    header: { Authorization: `Bearer ${token}`, 'X-Client-Type': 'wechat-miniprogram' },
    success: resolve,
    fail: reject
  }));
  let data;
  try { data = JSON.parse(response.data); } catch { throw new Error('图片上传响应无法解析'); }
  if (response.statusCode < 200 || response.statusCode >= 300 || !data.uploadedTo) {
    throw new Error(data.error || '图片上传失败');
  }
  return data.uploadedTo;
};

export const uploadPostImage = async () => { throw new Error('知行当前帖子接口只支持随帖子表单上传图片，暂不支持草稿图片预上传'); };

export const uploadAvatarImage = async (filePath) => {
  return { avatarUrl: await uploadProfileMedia(filePath, 'avatar') };
};

export const uploadBackgroundImage = async (filePath) => {
  return { url: await uploadProfileMedia(filePath, 'cover') };
};
