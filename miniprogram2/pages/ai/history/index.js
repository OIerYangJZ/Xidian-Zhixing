import { enterPage } from '../../../utils/motion';
import { formatTime, truncate } from '../../../utils/format';
import { clearBrowseHistory, getBrowseHistory } from '../../../utils/browse_history';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    rows: []
  },

  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadData();
  },

  loadData() {
    const rows = getBrowseHistory().map((item) => ({
      ...item,
      titleText: truncate(item.title, 48),
      summaryText: truncate(item.summary, 90),
      avatarInitial: String(item.authorAlias || '西').slice(0, 1),
      timeText: formatTime(item.viewedAt)
    }));
    this.setData({ rows });
  },

  clearHistory() {
    wx.showModal({
      title: '清空历史记录',
      content: '确认清空全部浏览记录？',
      confirmText: '清空',
      confirmColor: '#f4212e',
      success: (result) => {
        if (!result.confirm) return;
        clearBrowseHistory();
        this.setData({ rows: [] });
      }
    });
  },

  openPost(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  }
});
