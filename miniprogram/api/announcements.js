import request from '../utils/request';
import { getData, toArray } from '../utils/format';

export const getAnnouncementList = async (params = {}) => {
  const response = await request.get('/api/announcements', params);
  return toArray(getData(response, []));
};

export const getAnnouncementDetail = async (id) => {
  const response = await request.get(`/api/announcements/${id}`);
  return getData(response, {});
};

export const getAnnouncementFilters = async () => {
  const response = await request.get('/api/announcements/filters');
  return getData(response, {});
};

export const getDailySummary = async () => {
  const response = await request.get('/api/announcements/daily-summary');
  return getData(response, {});
};

export const summarizeAnnouncement = async (id) => {
  const response = await request.post(`/api/ai/announcements/${id}/summary`, {});
  return getData(response, {});
};
