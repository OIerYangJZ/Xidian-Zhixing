import request from '../utils/request';
import {
  getData,
  normalizeComment,
  normalizePost,
  responseContractError,
  toArray
} from '../utils/format';

const requireBooleanField = (data, field, label) => {
  if (typeof data[field] !== 'boolean') {
    throw responseContractError(`${label}响应缺少 ${field}`);
  }
};

const requireNumberField = (data, field, label) => {
  if (typeof data[field] !== 'number' || !Number.isFinite(data[field])) {
    throw responseContractError(`${label}响应缺少有效的 ${field}`);
  }
};

const requireOk = (data, label) => {
  if (data.ok !== true) {
    throw responseContractError(`${label}响应未确认成功`);
  }
};

// A random anonymous nickname for 随机, from the server's word list.
export const getRandomAnonymousAlias = async () => {
  const response = await request.get('/api/posts/anonymous-alias');
  const alias = String((getData(response, {}) || {}).alias || '').trim();
  if (!alias) throw new Error('没有取到随机昵称');
  return alias;
};

export const getPosts = async (params = {}) => {
  const response = await request.get('/api/posts', params);
  const payload = getData(response);
  const rows = Array.isArray(payload)
    ? payload
    : (payload && Array.isArray(payload.items) ? payload.items : null);
  if (!rows) {
    throw responseContractError('帖子列表响应格式错误');
  }
  return rows.map(normalizePost);
};

export const getPost = async (postId) => {
  const response = await request.get(`/api/posts/${postId}`);
  return normalizePost(getData(response, {}));
};

export const getPostComments = async (postId, params = {}) => {
  const response = await request.get(`/api/posts/${postId}/comments`, params);
  return toArray(getData(response, [])).map(normalizeComment);
};

export const createPost = async (payload) => {
  const response = await request.post(
    '/api/posts',
    payload,
    { silentErrorToast: true }
  );
  return normalizePost(getData(response, {}));
};

export const createComment = async (postId, payload) => {
  const response = await request.post(`/api/posts/${postId}/comments`, payload);
  return normalizeComment(getData(response, {}));
};

export const togglePostLike = async (postId) => {
  const response = await request.post(`/api/posts/${postId}/like`, {});
  const data = getData(response, {});
  requireBooleanField(data, 'liked', '帖子点赞');
  return data;
};

export const toggleCommentLike = async (commentId) => {
  const response = await request.post(`/api/comments/${commentId}/like`, {});
  const data = getData(response, {});
  requireBooleanField(data, 'liked', '评论点赞');
  return data;
};

export const favoritePost = async (postId) => {
  const response = await request.post(`/api/posts/${postId}/favorite`, {});
  const data = getData(response, {});
  requireBooleanField(data, 'favorited', '帖子收藏');
  requireNumberField(data, 'favoriteCount', '帖子收藏');
  return data;
};

export const unfavoritePost = async (postId) => {
  const response = await request.delete(`/api/posts/${postId}/favorite`, {});
  const data = getData(response, {});
  requireOk(data, '取消收藏');
  requireNumberField(data, 'favoriteCount', '取消收藏');
  return data;
};

export const incrementPostView = async (postId) => {
  const response = await request.post(`/api/posts/${postId}/view`, {});
  const data = getData(response, {});
  requireOk(data, '浏览计数');
  requireNumberField(data, 'viewCount', '浏览计数');
  return data;
};

export const reportTarget = async (payload) => {
  const response = await request.post('/api/reports', payload);
  const data = getData(response, {});
  requireOk(data, '举报');
  if (typeof data.id !== 'string' || !data.id.trim()) {
    throw responseContractError('举报响应缺少 ID');
  }
  return data;
};

export const getFavoritePosts = async () => {
  const response = await request.get('/api/posts/favorites');
  return toArray(getData(response, [])).map(normalizePost);
};

export const updatePost = async (postId, payload) => {
  const response = await request.patch(`/api/posts/${postId}`, payload);
  return normalizePost(getData(response, {}));
};

export const deletePost = async (postId) => {
  const response = await request.delete(`/api/posts/${postId}`, {});
  const data = getData(response, {});
  requireOk(data, '删除帖子');
  return data;
};

export const deleteComment = async (commentId) => {
  const response = await request.delete(`/api/comments/${commentId}`, {});
  const data = getData(response, {});
  requireOk(data, '删除评论');
  return data;
};
