const PENDING_AI_ENTRY_KEY = 'pendingAiWorkspaceEntry';

export const openAiWorkspace = (entry = {}) => {
  wx.setStorageSync(PENDING_AI_ENTRY_KEY, {
    prompt: String(entry.prompt || ''),
    answer: String(entry.answer || ''),
    title: String(entry.title || '')
  });
  wx.switchTab({ url: '/pages/ai/index' });
};

export const takePendingAiEntry = () => {
  const entry = wx.getStorageSync(PENDING_AI_ENTRY_KEY);
  if (!entry || typeof entry !== 'object') return null;
  wx.removeStorageSync(PENDING_AI_ENTRY_KEY);
  return entry;
};
