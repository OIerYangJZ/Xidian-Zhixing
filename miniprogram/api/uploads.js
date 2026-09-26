import request from '../utils/request';
import { getData, resolveUrl, responseContractError } from '../utils/format';

const fileNameFromPath = (filePath, fallback) => {
  const cleanPath = String(filePath || '').split('?')[0];
  const name = cleanPath.split('/').filter(Boolean).pop();
  return name || fallback;
};

const readFileBase64 = (filePath) => {
  return new Promise((resolve, reject) => {
    wx.getFileSystemManager().readFile({
      filePath,
      encoding: 'base64',
      success: (res) => resolve(res.data),
      fail: reject
    });
  });
};

const uploadLocalImage = async (filePath, options = {}) => {
  const fileName = options.fileName || fileNameFromPath(filePath, 'image.jpg');
  const dataBase64 = await readFileBase64(filePath);
  // No contentType: the server reads the type from the bytes and refuses a
  // declared one that disagrees, and a temp file's extension can be missing
  // or wrong.
  const response = await request.post(options.url, {
    dataBase64,
    fileName,
    ...(options.extra || {})
  });
  return getData(response, {});
};

export const uploadPostImage = async (filePath, options = {}) => {
  const upload = await uploadLocalImage(filePath, {
    ...options,
    url: '/api/uploads/images'
  });
  const result = {
    ...upload,
    url: resolveUrl(upload.url)
  };
  if (!String(result.id || '').trim()) {
    throw responseContractError('图片上传响应缺少 ID');
  }
  return result;
};

export const uploadAvatarImage = async (filePath, options = {}) => {
  const upload = await uploadLocalImage(filePath, {
    ...options,
    url: '/api/users/avatar'
  });
  const result = {
    ...upload,
    avatarUrl: resolveUrl(upload.avatarUrl)
  };
  if (!result.avatarUrl) {
    throw responseContractError('头像上传响应缺少地址');
  }
  return result;
};

export const uploadBackgroundImage = async (filePath, options = {}) => {
  const upload = await uploadLocalImage(filePath, {
    ...options,
    url: '/api/uploads/images'
  });
  const status = String(upload.status || '').trim().toLowerCase();
  if (status !== 'approved') {
    throw responseContractError(
      String(upload.moderationReason || '').trim() || '背景图片尚未通过审核'
    );
  }
  const result = {
    ...upload,
    path: upload.url,
    url: resolveUrl(upload.url)
  };
  if (!result.url) {
    throw responseContractError('背景图片上传响应缺少地址');
  }
  return result;
};
