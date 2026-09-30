import { enterPage } from '../../../utils/motion';
import { getMyClubApplications, submitClubApplication } from '../../../api/clubs';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const statusText = (status) => {
  if (status === 'approved') return '已通过';
  if (status === 'rejected') return '未通过';
  return '待审核';
};

Page({
  data: {
    name: '',
    category: '',
    description: '',
    contact: '',
    applications: [],
    themeClass: '',
    loading: true,
    errorMessage: '',
    submitting: false
  },
  async onLoad() {
    await this.loadApplications();
  },
  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
  },
  async loadApplications() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const applications = await getMyClubApplications();
      this.setData({
        applications: applications.map((item) => ({
          ...item,
          statusText: statusText(item.status)
        })),
        loading: false
      });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '申请记录加载失败，请重试'
      });
    }
  },
  retryLoad() {
    this.loadApplications();
  },
  onInput(event) {
    this.setData({ [event.currentTarget.dataset.field]: event.detail.value });
  },
  async submit() {
    if (this.data.submitting) return;
    this.setData({ submitting: true });
    try {
      await submitClubApplication({
        name: this.data.name,
        category: this.data.category,
        description: this.data.description,
        contact: this.data.contact
      });
      wx.showToast({ title: '已提交', icon: 'success' });
      this.setData({ name: '', category: '', description: '', contact: '' });
      await this.loadApplications();
    } catch (error) {
      this.setData({
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '社团申请提交失败，请重试'
      });
    } finally {
      this.setData({ submitting: false });
    }
  }
});
