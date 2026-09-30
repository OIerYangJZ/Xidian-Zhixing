const STORAGE_KEY = 'browseHistory';
const MAX_ITEMS = 100;

const readRows = () => {
  const rows = wx.getStorageSync(STORAGE_KEY);
  return Array.isArray(rows) ? rows : [];
};

export const getBrowseHistory = () => readRows();

export const recordPostView = (post = {}) => {
  const id = String(post.id || '').trim();
  if (!id) return;
  const content = String(post.content || '').trim();
  const row = {
    id,
    title: String(post.displayTitle || post.title || content.slice(0, 60) || '帖子'),
    summary: content.slice(0, 160),
    authorAlias: String(post.authorAlias || '西电同学'),
    authorAvatarUrl: String(post.authorAvatarUrl || ''),
    sectionName: String(post.sectionName || post.channel || ''),
    viewedAt: new Date().toISOString()
  };
  const rows = [row, ...readRows().filter((item) => String(item.id) !== id)].slice(0, MAX_ITEMS);
  wx.setStorageSync(STORAGE_KEY, rows);
};

export const clearBrowseHistory = () => wx.removeStorageSync(STORAGE_KEY);
