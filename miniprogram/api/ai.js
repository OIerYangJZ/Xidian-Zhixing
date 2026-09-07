import request from '../utils/request';
import { getData, toArray } from '../utils/format';

export const DEFAULT_AI_CONFIG = {
  model: '',
  models: [],
  configured: false
};

export const getAiConfig = () => ({
  ...DEFAULT_AI_CONFIG,
  ...(wx.getStorageSync('aiServerStatus') || {})
});

export const saveAiConfig = (config) => {
  const next = { ...DEFAULT_AI_CONFIG, ...(config || {}) };
  wx.setStorageSync('aiServerStatus', next);
  return next;
};

export const clearAiConfig = () => {
  wx.removeStorageSync('aiServerStatus');
};

export const fetchAiModels = async () => {
  const response = await request.get('/api/ai/models', {}, { timeout: 25000 });
  const data = getData(response, {});
  const status = {
    configured: Boolean(data.currentModel),
    model: String(data.currentModel || '').trim(),
    models: toArray(data.models).map((item) => String(item || '').trim()).filter(Boolean)
  };
  saveAiConfig(status);
  return status;
};

export const sendAiMessage = (content, options = {}) => {
  return request.post('/api/ai/chat', {
    content,
    messages: options.messages || []
  }, { timeout: 165000 });
};

export const askAiWithPostSelection = (payload) => {
  return request.post('/api/ai/post-selection', payload, { timeout: 165000 });
};
