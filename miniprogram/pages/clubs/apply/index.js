import { getMyClubApplications, submitClubApplication } from '../../../api/clubs';
import { requireLoginPage } from '../../../utils/auth_guard';
import { formatTime } from '../../../utils/format';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const STATUS = {
  approved: ['已通过', 'success'],
  rejected: ['未通过', 'neutral'],
  pending: ['待审核', 'accent']
};

const messageOf = (error, fallback) => (error && error.data && error.data.message)
  || (error && error.message)
  || fallback;

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
    submitError: '',
    submitting: false
  },
  async onLoad() {
    if (!requireLoginPage()) return;
    await this.loadApplications();
  },
  onShow() {
    applyThemeAndLanguage(this);
  },
  async loadApplications() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const applications = await getMyClubApplications();
      this.setData({
        applications: applications.map((item) => {
          const [statusText, statusTone] = STATUS[item.status] || STATUS.pending;
          return { ...item, statusText, statusTone, timeText: formatTime(item.createdAt) };
        }),
        loading: false
      });
    } catch (error) {
      this.setData({ loading: false, errorMessage: messageOf(error, '申请记录加载失败，请重试') });
    }
  },
  retryLoad() {
    this.loadApplications();
  },
  onInput(event) {
    this.setData({ [event.currentTarget.dataset.field]: event.detail.value, submitError: '' });
  },
  async submit() {
    if (this.data.submitting) return;
    const name = this.data.name.trim();
    const description = this.data.description.trim();
    if (!name || !description) {
      this.setData({ submitError: '请填写社团名称和申请说明' });
      return;
    }
    this.setData({ submitting: true, submitError: '' });
    try {
      await submitClubApplication({
        name,
        category: this.data.category.trim(),
        description,
        contact: this.data.contact.trim()
      });
      wx.showToast({ title: '已提交', icon: 'success' });
      this.setData({ name: '', category: '', description: '', contact: '' });
      await this.loadApplications();
    } catch (error) {
      this.setData({ submitError: messageOf(error, '社团申请提交失败，请重试') });
    } finally {
      this.setData({ submitting: false });
    }
  }
});
