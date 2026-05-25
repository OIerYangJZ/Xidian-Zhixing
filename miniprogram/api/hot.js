import request from '../utils/request';
import { getData, toArray } from '../utils/format';

export const getHotTopics = async () => {
  const response = await request.get('/api/hot-topics');
  return toArray(getData(response, []));
};

export const getHotTopicSummary = async () => {
  const response = await request.get('/api/ai/hot-topics/summary');
  return getData(response, {});
};
