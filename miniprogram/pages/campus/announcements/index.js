import { getAnnouncementDailySummary, getAnnouncementTypes, getAnnouncements } from '../../../api/announcements';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

// 校园公告: today's summary, a type filter, then the list, newest first.
Page({
  data: {
    loading: true,
    errorMessage: '',
    items: [],
    types: [],
    activeType: '',
    summary: ''
  },

  onLoad() {
    if (!requireLoginPage()) return;
    this.loadAll();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  onPullDownRefresh() {
    this.loadAll().finally(() => wx.stopPullDownRefresh());
  },

  async loadAll() {
    this.setData({ loading: !this.data.items.length, errorMessage: '' });
    try {
      const [items, types, daily] = await Promise.all([
        getAnnouncements(this.data.activeType),
        getAnnouncementTypes().catch(() => []),
        getAnnouncementDailySummary().catch(() => null)
      ]);
      this.setData({ items, types, summary: daily ? daily.summary : '', loading: false });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message) || (error && error.message) || '公告加载失败，请重试'
      });
    }
  },

  async onTypeTap(event) {
    const type = event.currentTarget.dataset.type || '';
    if (type === this.data.activeType) return;
    this.setData({ activeType: type });
    const requested = type;
    try {
      const items = await getAnnouncements(type);
      // A later tap wins.
      if (this.data.activeType === requested) this.setData({ items });
    } catch (error) {}
  },

  retryLoad() {
    this.loadAll();
  },

  openAnnouncement(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/announcement/index?id=${encodeURIComponent(id)}` });
  }
});
