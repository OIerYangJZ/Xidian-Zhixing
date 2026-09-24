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

// Id that lets cancelAiMessage reach a sendAiMessage still in flight.
export const newAiRequestId = () => {
  let id = '';
  for (let i = 0; i < 32; i += 1) id += Math.floor(Math.random() * 16).toString(16);
  return id;
};

export const sendAiMessage = (content, options = {}) => {
  return request.post('/api/ai/chat', {
    ...(options.requestId ? { requestId: options.requestId } : {}),
    content,
    messages: options.messages || []
  }, { timeout: 165000 });
};

// Stops a sendAiMessage on the server, which drops the model provider's
// connection so the answer stops generating (and being billed). The pending
// sendAiMessage then fails with a 409 the caller should ignore.
export const cancelAiMessage = (requestId) => {
  return request.post('/api/ai/chat/cancel', { requestId }, { timeout: 15000 });
};

export const askAiWithPostSelection = (payload) => {
  return request.post('/api/ai/post-selection', payload, { timeout: 165000 });
};
