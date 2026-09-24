import { formatTime, truncate } from '../../../utils/format';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    rows: []
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadData();
  },

  loadData() {
    const rows = (wx.getStorageSync('aiHistory') || []).map((item) => ({
      ...item,
      // A renamed entry shows its title instead of the question.
      questionText: truncate(item.title || item.question, 42),
      answerText: truncate(item.answer, 80),
      timeText: formatTime(item.createdAt)
    }));
    this.setData({ rows });
  },

  // Entries are keyed by createdAt, as in the list's wx:key.
  updateStored(createdAt, change) {
    const rows = (wx.getStorageSync('aiHistory') || [])
      .map((item) => (item && item.createdAt === createdAt ? change(item) : item))
      .filter(Boolean);
    wx.setStorageSync('aiHistory', rows);
    this.loadData();
  },

  openActions(event) {
    const { createdAt } = event.currentTarget.dataset;
    const row = this.data.rows.find((item) => item.createdAt === createdAt);
    if (!row) return;
    wx.showActionSheet({
      itemList: ['重命名', '删除'],
      success: (res) => {
        if (res.tapIndex === 0) this.renameEntry(row);
        if (res.tapIndex === 1) this.deleteEntry(row);
      }
    });
  },

  renameEntry(row) {
    wx.showModal({
      title: '重命名',
      editable: true,
      placeholderText: '输入新的名称',
      content: row.title || row.question,
      success: (res) => {
        const title = String(res.content || '').trim().slice(0, 40);
        if (!res.confirm || !title) return;
        this.updateStored(row.createdAt, (item) => ({ ...item, title }));
      }
    });
  },

  deleteEntry(row) {
    wx.showModal({
      title: '删除这条记录？',
      content: '会从本机删除这次问答。',
      confirmText: '删除',
      confirmColor: '#97382F',
      success: (res) => {
        if (!res.confirm) return;
        this.updateStored(row.createdAt, () => null);
      }
    });
  },

  clearHistory() {
    wx.removeStorageSync('aiHistory');
    this.setData({ rows: [] });
  },

  openChat(event) {
    const question = event.currentTarget.dataset.question;
    wx.navigateTo({ url: `/pages/ai/chat/index?q=${encodeURIComponent(question)}` });
  }
});
