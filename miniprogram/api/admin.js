import request from '../utils/request';
import { getData, resolveUrl, responseContractError, toArray } from '../utils/format';

const adminOptions = { keepSessionOnUnauthorized: true };
// The backend waits up to 300 s (upsert) / 600 s (reindex) on the knowledge
// service, so these calls must outlast that instead of the default 15 s.
const knowledgeWriteOptions = { ...adminOptions, timeout: 310 * 1000 };
const knowledgeReindexOptions = { ...adminOptions, timeout: 610 * 1000 };

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

export const getAdminFeedbacks = async (params = {}) => {
  const response = await request.get('/api/admin/feedbacks', params, adminOptions);
  return toArray(getData(response, []));
};

// payload: { action: 'reply' | 'close', reply }
export const handleAdminFeedback = async (id, payload) => {
  const response = await request.post(`/api/admin/feedbacks/${id}/handle`, payload, adminOptions);
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

export const getTags = async () => {
  const response = await request.get('/api/admin/tags', {}, adminOptions);
  const data = getData(response, {});
  if (!Array.isArray(data.tags)) {
    throw responseContractError('标签列表响应缺少 tags');
  }
  return data.tags;
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
  return getData(response, {});
};

export const updateAdminConfig = async (payload) => {
  const response = await request.patch('/api/admin/config', payload, adminOptions);
  return getData(response, {});
};

export const createKnowledgeSource = async (payload) => {
  const response = await request.post('/api/admin/ai/knowledge-sources', payload, knowledgeWriteOptions);
  return getData(response, {});
};

export const getKnowledgeSources = async () => {
  const response = await request.get('/api/admin/ai/knowledge-sources', {}, adminOptions);
  return getData(response, { items: [], index: {} });
};

export const updateKnowledgeSource = async (id, payload) => {
  const response = await request.patch(`/api/admin/ai/knowledge-sources/${encodeURIComponent(id)}`, payload, knowledgeWriteOptions);
  return getData(response, {});
};

export const deleteKnowledgeSource = async (id) => {
  const response = await request.delete(`/api/admin/ai/knowledge-sources/${encodeURIComponent(id)}`, {}, adminOptions);
  return getData(response, {});
};

export const reindexKnowledge = async () => {
  const response = await request.post('/api/admin/ai/reindex', {}, knowledgeReindexOptions);
  return getData(response, {});
};

// ---- 公告 ----

export const getAdminAnnouncements = async () => {
  const response = await request.get('/api/admin/announcements', {}, adminOptions);
  return toArray(getData(response, []));
};

// {title, content, type?, isImportant?}; primary admins only.
export const publishAnnouncement = async (payload) => {
  const response = await request.post('/api/admin/announcements', payload, adminOptions);
  return getData(response, {});
};

// ---- 分区 ----
// Named by sectionId, which never changes.  GET /api/sections lists enabled
// sections only, so a disabled one drops out of this list.

export const getSections = async () => {
  const response = await request.get('/api/sections', {}, adminOptions);
  return toArray(getData(response, []));
};

// {sectionType, sectionId, name, description?, ruleText?, sortOrder?}; 409 if the sectionId is taken.
export const createSection = async (payload) => {
  const response = await request.post('/api/sections', payload, adminOptions);
  return getData(response, {});
};

export const updateSection = async (sectionId, payload) => {
  const response = await request.patch(`/api/sections/${encodeURIComponent(sectionId)}`, payload, adminOptions);
  return getData(response, {});
};

// ---- 管理员账号 (primary admins only) ----

export const getAdminAccounts = async () => {
  const response = await request.get('/api/admin/admin-accounts', {}, adminOptions);
  return toArray(getData(response, []));
};

export const createAdminAccount = async (username, password) => {
  const response = await request.post('/api/admin/admin-accounts', { username, password }, adminOptions);
  return getData(response, {});
};

// action: 'activate' | 'deactivate'
export const actAdminAccount = async (id, action) => {
  const response = await request.post(`/api/admin/admin-accounts/${encodeURIComponent(id)}/action`, { action }, adminOptions);
  return getData(response, {});
};

// ---- 导出 / 热榜 / AI 追踪 ----

// {format, fileName, contentType, rowCount, data}: the file's text in `data`.
export const exportAdminData = async (params = {}) => {
  const response = await request.get('/api/admin/export', params, adminOptions);
  const data = getData(response, {});
  if (typeof data.data !== 'string' || !data.fileName) {
    throw responseContractError('导出响应缺少文件内容');
  }
  return data;
};

export const rebuildHotTopics = async () => {
  const response = await request.post('/api/hot-topics/rebuild', {}, adminOptions);
  return toArray(getData(response, []));
};

// One AI answer's retrieval trace, by the traceId its chat response carried.
export const getAiTrace = async (traceId) => {
  const response = await request.get(`/api/admin/ai/traces/${encodeURIComponent(traceId)}`, {}, adminOptions);
  return getData(response, {});
};
