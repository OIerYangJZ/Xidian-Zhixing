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
    themeClass: ''
  },
  async onLoad() {
    this.loadApplications();
  },
  onShow() {
    applyThemeAndLanguage(this);
  },
  async loadApplications() {
    const applications = await getMyClubApplications();
    this.setData({
      applications: applications.map((item) => ({
        ...item,
        statusText: statusText(item.status)
      }))
    });
  },
  onInput(event) {
    this.setData({ [event.currentTarget.dataset.field]: event.detail.value });
  },
  async submit() {
    await submitClubApplication({
      name: this.data.name,
      category: this.data.category,
      description: this.data.description,
      contact: this.data.contact
    });
    wx.showToast({ title: '已提交', icon: 'success' });
    this.setData({ name: '', category: '', description: '', contact: '' });
    this.loadApplications();
  }
});
