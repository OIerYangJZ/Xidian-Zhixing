import request from '../utils/request';
import { getData, normalizePost, responseContractError } from '../utils/format';

const normalizeLegacyPost = (raw = {}) => {
  const post = normalizePost(raw);
  return {
    ...post,
    authorName: post.authorAlias,
    images: post.imageUrls,
    isLiked: post.liked,
    isFavorited: post.favorited
  };
};

const normalizeLegacyPostListResponse = (response) => {
  const payload = getData(response);
  const rows = Array.isArray(payload)
    ? payload
    : (payload && Array.isArray(payload.items) ? payload.items : null);
  if (!rows) {
    throw responseContractError('帖子列表响应格式错误');
  }
  return {
    ...response,
    data: {
      ...(Array.isArray(payload) ? {} : payload),
      items: rows.map(normalizeLegacyPost)
    }
  };
};

/**
 * 获取帖子列表
 * @param {Object} params - 分页或过滤参数，例如 { page: 1, limit: 10, keyword: '树洞' }
 */
export const getPosts = async (params = {}) => {
  const response = await request.get('/api/posts', params);
  return normalizeLegacyPostListResponse(response);
};
