import { requireLoginPage } from '../../../utils/auth_guard';
import { getMyFeedbacks, submitFeedback } from '../../../api/user';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { formatTime } from '../../../utils/format';

Page({
  data: {
    categories: ['学校服务意见', '校园设施反馈', '平台功能建议', '学校管理或流程建议', '其他反馈'],
    categoryIndex: 0,
    content: '',
    contact: '',
    records: [],
    loadingRecords: true,
    submitting: false
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadRecords();
  },

  async loadRecords() {
    this.setData({ loadingRecords: true });
    try {
      const records = await getMyFeedbacks();
      this.setData({
        records: records.map((item) => ({
          ...item,
          timeText: formatTime(item.createdAt),
          statusText: item.status === 'resolved' ? '已回复' : (item.status === 'closed' ? '已关闭' : '待处理')
        })),
        loadingRecords: false
      });
    } catch (error) {
      this.setData({ loadingRecords: false });
    }
  },

  onContentInput(event) {
    this.setData({ content: event.detail.value });
  },

  onContactInput(event) {
    this.setData({ contact: event.detail.value });
  },

  onCategoryChange(event) {
    this.setData({ categoryIndex: Number(event.detail.value || 0) });
  },

  async submitFeedback() {
    if (this.data.submitting) return;
    const content = this.data.content.trim();
    if (!content) {
      wx.showToast({ title: '请输入反馈内容', icon: 'none' });
      return;
    }
    this.setData({ submitting: true });
    try {
      await submitFeedback({
        category: this.data.categories[this.data.categoryIndex],
        content,
        contact: this.data.contact.trim()
      });
      wx.showToast({ title: '已提交反馈', icon: 'success' });
      this.setData({ content: '', contact: '', submitting: false });
      this.loadRecords();
    } catch (error) {
      this.setData({ submitting: false });
    }
  }
});
