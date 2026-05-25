import { getAnnouncementDetail, summarizeAnnouncement } from '../../../api/announcements';

Page({
  data: {
    id: '',
    item: null,
    aiSummary: ''
  },

  onLoad(options) {
    this.setData({ id: options.id || '' });
    this.loadDetail();
  },

  async loadDetail() {
    const item = await getAnnouncementDetail(this.data.id);
    this.setData({ item, aiSummary: item.aiSummary || '' });
  },

  async summarize() {
    const result = await summarizeAnnouncement(this.data.id);
    this.setData({ aiSummary: result.answer || '' });
    wx.showToast({ title: '摘要已生成', icon: 'success' });
  }
});
