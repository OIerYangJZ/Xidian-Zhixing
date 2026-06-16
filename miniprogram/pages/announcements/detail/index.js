import { getAnnouncementDetail, summarizeAnnouncement } from '../../../api/announcements';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { openAppTarget } from '../../../utils/navigation';

Page({
  data: {
    id: '',
    item: null,
    aiSummary: '',
    summarizing: false
  },

  onLoad(options) {
    this.setData({ id: options.id || '' });
    this.loadDetail();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  async loadDetail() {
    const item = await getAnnouncementDetail(this.data.id);
    this.setData({ item, aiSummary: item.aiSummary || '' });
  },

  async summarize() {
    if (this.data.summarizing) return;
    this.setData({ summarizing: true });
    try {
      const result = await summarizeAnnouncement(this.data.id);
      this.setData({ aiSummary: result.answer || '' });
      wx.showToast({ title: '摘要已生成', icon: 'success' });
    } finally {
      this.setData({ summarizing: false });
    }
  },

  openOriginal() {
    const item = this.data.item || {};
    const jumpUrl = String(item.jumpUrl || '').trim();
    const target = /^\/?pages\//.test(jumpUrl)
      ? { path: jumpUrl, url: item.originalUrl || '' }
      : { url: item.originalUrl || jumpUrl };
    if (!openAppTarget(target)) {
      wx.showToast({ title: '暂无原文链接', icon: 'none' });
    }
  }
});
