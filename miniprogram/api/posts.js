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

// One page of /api/posts; with page/limit the server answers { items, hasMore }.
export const getPostsPage = async (params = {}) => {
  const response = await request.get('/api/posts', params);
  const payload = getData(response);
  if (!payload || !Array.isArray(payload.items) || typeof payload.hasMore !== 'boolean') {
    throw responseContractError('帖子分页响应格式错误');
  }
  return {
    items: payload.items.map(normalizePost),
    hasMore: payload.hasMore,
    total: typeof payload.total === 'number' ? payload.total : payload.items.length
  };
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

export const setPostLiked = async (postId, liked) => {
  const response = await request.post(`/api/posts/${postId}/like`, { liked });
  const data = getData(response, {});
  requireBooleanField(data, 'liked', '帖子点赞');
  requireNumberField(data, 'likeCount', '帖子点赞');
  return data;
};

export const setCommentLiked = async (commentId, liked) => {
  const response = await request.post(`/api/comments/${commentId}/like`, { liked });
  const data = getData(response, {});
  requireBooleanField(data, 'liked', '评论点赞');
  return data;
};

export const favoritePost = async (postId) => {
  const response = await request.post(`/api/posts/${postId}/favorite`, { favorited: true });
  const data = getData(response, {});
  requireBooleanField(data, 'favorited', '帖子收藏');
  requireNumberField(data, 'favoriteCount', '帖子收藏');
  return data;
};

export const unfavoritePost = async (postId) => {
  const response = await request.delete(`/api/posts/${postId}/favorite`, {});
  const data = getData(response, {});
  requireOk(data, '取消收藏');
  requireBooleanField(data, 'favorited', '取消收藏');
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

// Sets the repost to `reposted` (not a toggle, so a stale list cannot flip it
// the wrong way).  Returns {reposted, repostCount}.
export const setPostReposted = async (postId, reposted) => {
  const response = await request.post(`/api/posts/${postId}/repost`, { reposted });
  const data = getData(response, {});
  requireBooleanField(data, 'reposted', '转发');
  requireNumberField(data, 'repostCount', '转发');
  return data;
};

export const updateComment = async (commentId, payload) => {
  const response = await request.patch(`/api/comments/${commentId}`, payload);
  return normalizeComment(getData(response, {}));
};

// A user's posts and reposts, newest first; each row says who reposted it.
export const getUserTimelinePage = async (userId, params = {}) => {
  const response = await request.get(`/api/users/${userId}/timeline`, params);
  const payload = getData(response, {});
  if (!Array.isArray(payload.items) || typeof payload.hasMore !== 'boolean') {
    throw responseContractError('主页动态响应格式错误');
  }
  return {
    items: payload.items.map((item) => ({
      ...normalizePost(item),
      repostedBy: item.repostedBy && item.repostedBy.userId ? item.repostedBy : null,
      eventKey: String(item.eventKey || item.id)
    })),
    hasMore: payload.hasMore
  };
};

// What the signed-in user did (posts, comments, likes, saves, reposts, follows).
export const getMyActivityPage = async (params = {}) => {
  const response = await request.get('/api/users/me/activity', params);
  const payload = getData(response, {});
  if (!Array.isArray(payload.items) || typeof payload.hasMore !== 'boolean') {
    throw responseContractError('互动记录响应格式错误');
  }
  return { items: payload.items, hasMore: payload.hasMore };
};

// 置顶. Level-one users pin at once ({mode: 'direct', post}); everyone else
// files a request for a moderator ({mode: 'pending', request}).
export const requestPostPin = async (postId, { durationMinutes, reason = '' }) => {
  const response = await request.post(`/api/posts/${postId}/pin-request`, { durationMinutes, reason });
  const data = getData(response, {});
  if (!['direct', 'pending'].includes(data.mode)) {
    throw responseContractError('置顶响应缺少 mode');
  }
  return data;
};
