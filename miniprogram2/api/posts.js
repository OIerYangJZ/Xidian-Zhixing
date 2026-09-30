import request from '../utils/request';
import {
  getData,
  normalizeComment,
  normalizePost,
  responseContractError,
  toArray
} from '../utils/format';
import { getCurrentUserId } from './session';

export const getPosts = async (params = {}) => {
  if (params.authorId) {
    const response = await request.get(`/api/users/${encodeURIComponent(params.authorId)}/posts`, {
      limit: params.limit || 30,
      offset: Math.max(0, ((Number(params.page) || 1) - 1) * (Number(params.limit) || 30))
    });
    return toArray(getData(response, [])).map(normalizePost);
  }
  if (params.keyword) {
    const tag = String(params.keyword).replace(/^#/, '').trim();
    const response = await request.get(`/api/posts/hashtag/${encodeURIComponent(tag)}`, params);
    return toArray(getData(response, [])).map(normalizePost);
  }
  const userId = await getCurrentUserId();
  const response = await request.get(`/api/users/${encodeURIComponent(userId)}/feed`, { limit: params.limit || 30 });
  const payload = getData(response);
  const rows = Array.isArray(payload)
    ? payload
    : (payload && Array.isArray(payload.items) ? payload.items : null);
  if (!rows) {
    throw responseContractError('帖子列表响应格式错误');
  }
  return rows.map(normalizePost);
};

export const getPostsPage = async (params = {}) => {
  const page = Number(params.page) || 1;
  const limit = Number(params.limit) || 20;
  const userId = await getCurrentUserId();
  const cursorKey = `zhixing-feed-cursor:${params.sort || 'latest'}:${params.sectionId || 'all'}`;
  if (page === 1) wx.removeStorageSync(cursorKey);
  const cursor = page > 1 ? wx.getStorageSync(cursorKey) : '';
  const query = {
    limit,
    ...(cursor ? { cursor } : {}),
    ...(params.sectionId ? { spaceId: params.sectionId } : {})
  };
  const response = params.sort === 'hot'
    ? await request.get('/api/posts/trending', query)
    : await request.get(`/api/users/${encodeURIComponent(userId)}/feed`, query);
  const payload = getData(response);
  const items = Array.isArray(payload) ? payload : payload && payload.items;
  if (!Array.isArray(items)) {
    throw responseContractError('分页帖子列表响应格式错误');
  }
  const last = items[items.length - 1];
  if (last && last.feedCursor) wx.setStorageSync(cursorKey, last.feedCursor);
  return {
    items: items.map(normalizePost),
    page,
    limit,
    total: page === 1 ? items.length : 0,
    hasMore: typeof payload.hasMore === 'boolean' ? payload.hasMore : items.length === limit
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
  if (payload.imageUploadIds && payload.imageUploadIds.length) {
    throw new Error('图片发布接口尚未对齐，当前请先发布纯文字帖子');
  }
  const response = await request.post('/api/posts', {
    content: payload.content,
    displayIdentity: payload.useAnonymousAlias ? 'ANONYMOUS' : 'USER'
  }, { silentErrorToast: true });
  return normalizePost(getData(response, {}));
};

export const createComment = async (postId, payload) => {
  const parentId = payload.parentId || payload.replyToCommentId;
  const response = parentId
    ? await request.post(`/api/comments/${parentId}/replies`, { content: payload.content })
    : await request.post(`/api/posts/${postId}/comments`, { content: payload.content });
  return normalizeComment(getData(response, {}));
};

export const togglePostLike = async (postId, currentlyLiked = false) => {
  const userId = await getCurrentUserId();
  const url = `/api/users/${encodeURIComponent(userId)}/liked-posts`;
  if (currentlyLiked) await request.delete(`${url}/${encodeURIComponent(postId)}`, {});
  else await request.post(url, { postId: Number(postId) });
  return { liked: !currentlyLiked };
};

export const toggleCommentLike = async (commentId, currentlyLiked = false) => {
  const userId = await getCurrentUserId();
  const url = `/api/users/${encodeURIComponent(userId)}/liked-comments`;
  if (currentlyLiked) await request.delete(`${url}/${encodeURIComponent(commentId)}`, {});
  else await request.post(url, { commentId: Number(commentId) });
  return { liked: !currentlyLiked };
};

export const togglePostRepost = async (postId, currentlyReposted = false) => {
  const userId = await getCurrentUserId();
  const url = `/api/users/${encodeURIComponent(userId)}/reposts`;
  if (currentlyReposted) await request.delete(`${url}/${encodeURIComponent(postId)}`, {});
  else await request.post(url, { postId: Number(postId) });
  return { reposted: !currentlyReposted };
};

export const favoritePost = async (postId) => {
  const userId = await getCurrentUserId();
  await request.post(`/api/users/${encodeURIComponent(userId)}/bookmarks`, { postId: Number(postId) });
  return { favorited: true };
};

export const unfavoritePost = async (postId) => {
  const userId = await getCurrentUserId();
  await request.delete(`/api/users/${encodeURIComponent(userId)}/bookmarks/${encodeURIComponent(postId)}`, {});
  return { favorited: false };
};

export const incrementPostView = async (postId) => {
  const response = await request.post(`/api/posts/${postId}`, {});
  const data = getData(response, {});
  return { ...data, ok: true };
};

export const reportTarget = async (payload) => {
  const reasonMap = {
    '广告引流': 'SPAM', '垃圾信息': 'SPAM', '人身攻击': 'HARASSMENT',
    '违规内容': 'INAPPROPRIATE_CONTENT', '其他': 'OTHER'
  };
  const response = await request.post('/api/reports', {
    [payload.targetType === 'comment' ? 'commentId' : 'postId']: Number(payload.targetId),
    reason: reasonMap[payload.reason] || 'OTHER',
    details: payload.description || ''
  });
  const data = getData(response, {});
  if (data.id === undefined || data.id === null) {
    throw responseContractError('举报响应缺少 ID');
  }
  return data;
};

export const getFavoritePosts = async () => {
  const userId = await getCurrentUserId();
  const response = await request.get(`/api/users/${encodeURIComponent(userId)}/bookmarks`);
  return toArray(getData(response, [])).map(normalizePost);
};

export const updatePost = async (postId, payload) => {
  const response = await request.patch(`/api/posts/${postId}`, payload);
  return normalizePost(getData(response, {}));
};

export const deletePost = async (postId) => {
  const response = await request.delete(`/api/posts/${postId}`, {});
  const data = getData(response, {});
  if (data.id === undefined || data.id === null) throw responseContractError('删除帖子响应缺少 ID');
  return data;
};

export const deleteComment = async (commentId) => {
  const response = await request.delete(`/api/comments/${commentId}`, {});
  const data = getData(response, {});
  if (data.id === undefined || data.id === null) throw responseContractError('删除评论响应缺少 ID');
  return data;
};
