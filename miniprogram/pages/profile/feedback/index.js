import { requireLoginPage } from '../../../utils/auth_guard';
import { submitFeedback } from '../../../api/user';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    categories: ['学校服务意见', '校园设施反馈', '平台功能建议', '学校管理或流程建议', '其他反馈'],
    categoryIndex: 0,
    content: '',
    contact: '',
    submitting: false
  },

  onShow() {
    applyThemeAndLanguage(this);
    requireLoginPage();
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
      setTimeout(() => {
        wx.navigateBack({ fail: () => wx.navigateTo({ url: '/pages/profile/index' }) });
      }, 700);
    } catch (error) {
      this.setData({ submitting: false });
    }
  }
});
