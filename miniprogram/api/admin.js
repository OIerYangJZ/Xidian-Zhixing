import request from '../utils/request';
import { getData, resolveUrl, toArray } from '../utils/format';

const adminOptions = { keepSessionOnUnauthorized: true };

const normalizeImage = (item = {}) => ({
  ...item,
  id: String(item.id || ''),
  url: resolveUrl(item.url || '')
});

export const getCurrentAdmin = async () => {
  const response = await request.get('/api/admin/auth/me', {}, adminOptions);
  return getData(response, {});
};

export const getAdminOverview = async () => {
  const response = await request.get('/api/admin/overview', {}, adminOptions);
  return getData(response, {});
};

export const getAdminReviews = async (params = {}) => {
  const response = await request.get('/api/admin/reviews', params, adminOptions);
  return toArray(getData(response, []));
};

export const handleAdminReview = async ({ type, id, action }) => {
  const response = await request.post(`/api/admin/reviews/${type}/${id}/${action}`, {}, adminOptions);
  return getData(response, {});
};

export const handleAdminReviewBatch = async (payload) => {
  const response = await request.post('/api/admin/reviews/batch', payload, adminOptions);
  return getData(response, {});
};

export const getAdminReports = async (params = {}) => {
  const response = await request.get('/api/admin/reports', params, adminOptions);
  return toArray(getData(response, []));
};

export const handleAdminReport = async (id, payload) => {
  const response = await request.post(`/api/admin/reports/${id}/handle`, payload, adminOptions);
  return getData(response, {});
};

export const getAdminImages = async (params = {}) => {
  const response = await request.get('/api/admin/images/reviews', params, adminOptions);
  return toArray(getData(response, [])).map(normalizeImage);
};

export const handleAdminImage = async (id, payload) => {
  const response = await request.post(`/api/admin/images/${id}/review`, payload, adminOptions);
  return getData(response, {});
};

export const getAdminUsers = async () => {
  const response = await request.get('/api/admin/users', {}, adminOptions);
  return toArray(getData(response, []));
};

export const handleAdminUser = async (id, payload) => {
  const response = await request.post(`/api/admin/users/${id}/action`, payload, adminOptions);
  return getData(response, {});
};

export const getPostPinRequests = async (params = {}) => {
  const response = await request.get('/api/admin/post-pin-requests', params, adminOptions);
  return toArray(getData(response, []));
};

export const handlePostPinRequest = async (id, payload) => {
  const response = await request.post(`/api/admin/post-pin-requests/${id}/handle`, payload, adminOptions);
  return getData(response, {});
};

export const getUserLevelRequests = async (params = {}) => {
  const response = await request.get('/api/admin/user-level-requests', params, adminOptions);
  return toArray(getData(response, []));
};

export const handleUserLevelRequest = async (id, payload) => {
  const response = await request.post(`/api/admin/user-level-requests/${id}/handle`, payload, adminOptions);
  return getData(response, {});
};

export const getCancellationRequests = async (params = {}) => {
  const response = await request.get('/api/admin/account-cancellation-requests', params, adminOptions);
  return toArray(getData(response, []));
};

export const handleCancellationRequest = async (id, payload) => {
  const response = await request.post(`/api/admin/account-cancellation-requests/${id}/handle`, payload, adminOptions);
  return getData(response, {});
};

export const getAdminAppeals = async (params = {}) => {
  const response = await request.get('/api/admin/appeals', params, adminOptions);
  return toArray(getData(response, []));
};

export const handleAdminAppeal = async (id, payload) => {
  const response = await request.post(`/api/admin/appeals/${id}/handle`, payload, adminOptions);
  return getData(response, {});
};

export const getClubApplications = async (params = {}) => {
  const response = await request.get('/api/admin/clubs/applications', params, adminOptions);
  return toArray(getData(response, []));
};

export const handleClubApplication = async (id, payload) => {
  const response = await request.post(`/api/admin/clubs/applications/${id}/handle`, payload, adminOptions);
  return getData(response, {});
};

export const getChannelsTags = async () => {
  const response = await request.get('/api/admin/channels-tags', {}, adminOptions);
  return getData(response, { channels: [], tags: [] });
};

export const addChannel = async (channel) => {
  const response = await request.post('/api/admin/channels', { channel }, adminOptions);
  return getData(response, {});
};

export const renameChannel = async (oldName, channel) => {
  const response = await request.patch(`/api/admin/channels/${encodeURIComponent(oldName)}`, { channel }, adminOptions);
  return getData(response, {});
};

export const deleteChannel = async (name) => {
  const response = await request.delete(`/api/admin/channels/${encodeURIComponent(name)}`, {}, adminOptions);
  return getData(response, {});
};

export const addTag = async (tag) => {
  const response = await request.post('/api/admin/tags', { tag }, adminOptions);
  return getData(response, {});
};

export const renameTag = async (oldName, tag) => {
  const response = await request.patch(`/api/admin/tags/${encodeURIComponent(oldName)}`, { tag }, adminOptions);
  return getData(response, {});
};

export const deleteTag = async (name) => {
  const response = await request.delete(`/api/admin/tags/${encodeURIComponent(name)}`, {}, adminOptions);
  return getData(response, {});
};

export const getAdminConfig = async () => {
  const response = await request.get('/api/admin/config', {}, adminOptions);
  return getData(response, { sensitiveWords: [], rateLimitRules: {} });
};

export const updateAdminConfig = async (payload) => {
  const response = await request.patch('/api/admin/config', payload, adminOptions);
  return getData(response, {});
};

export const createKnowledgeSource = async (payload) => {
  const response = await request.post('/api/admin/ai/knowledge-sources', payload, adminOptions);
  return getData(response, {});
};

export const getKnowledgeSources = async () => {
  const response = await request.get('/api/admin/ai/knowledge-sources', {}, adminOptions);
  return getData(response, { items: [], index: {} });
};

export const updateKnowledgeSource = async (id, payload) => {
  const response = await request.patch(`/api/admin/ai/knowledge-sources/${encodeURIComponent(id)}`, payload, adminOptions);
  return getData(response, {});
};

export const deleteKnowledgeSource = async (id) => {
  const response = await request.delete(`/api/admin/ai/knowledge-sources/${encodeURIComponent(id)}`, {}, adminOptions);
  return getData(response, {});
};

export const reindexKnowledge = async () => {
  const response = await request.post('/api/admin/ai/reindex', {}, adminOptions);
  return getData(response, {});
};
