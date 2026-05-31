import { getMyClubApplications, submitClubApplication } from '../../../api/clubs';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

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
    this.setData({ applications: await getMyClubApplications() });
  },
  onShow() {
    applyThemeAndLanguage(this);
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
    this.setData({ applications: await getMyClubApplications(), name: '', category: '', description: '', contact: '' });
  }
});
