import request from '../utils/request';
import { formatTime, getData, responseContractError, toArray, truncate } from '../utils/format';

// 校园公告 (GET /api/announcements…), published by administrators.
const normalizeAnnouncement = (raw = {}) => {
  const id = String(raw.id || '').trim();
  if (!id) throw responseContractError('公告数据缺少 ID');
  const content = String(raw.content || '');
  return {
    ...raw,
    id,
    title: String(raw.title || '公告'),
    content,
    summaryText: String(raw.summary || raw.aiSummary || '') || truncate(content, 80),
    type: String(raw.type || '系统公告'),
    isImportant: Boolean(raw.isImportant),
    timeText: formatTime(raw.publishedAt || raw.createdAt)
  };
};

export const getAnnouncements = async (type = '') => {
  const response = await request.get('/api/announcements', type ? { type } : {});
  return toArray(getData(response, [])).map(normalizeAnnouncement);
};

export const getAnnouncementTypes = async () => {
  const response = await request.get('/api/announcements/filters');
  return toArray(getData(response, {}).types).map((item) => String(item));
};

export const getAnnouncementDailySummary = async () => {
  const response = await request.get('/api/announcements/daily-summary');
  const data = getData(response, {});
  return { title: String(data.title || '今日公告摘要'), summary: String(data.summary || '') };
};

export const getAnnouncement = async (id) => {
  const response = await request.get(`/api/announcements/${encodeURIComponent(id)}`);
  return normalizeAnnouncement(getData(response, {}));
};
