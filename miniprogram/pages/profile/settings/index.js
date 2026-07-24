import { getUserInfo, logout } from '../../../api/auth';
import { clearLocalSession, requireLoginPage } from '../../../utils/auth_guard';
import { avatarInitial } from '../../../utils/format';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    loading: false,
    loggingOut: false,
    userInfo: null,
    errorMessage: ''
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    applyThemeAndLanguage(this);
    this.fetchUserInfo();
  },

  async fetchUserInfo() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const res = await getUserInfo();
      const nickname = res.data.nickname || res.data.alias || '';
      this.setData({
        userInfo: {
          ...res.data,
          avatarInitial: avatarInitial(nickname)
        },
        errorMessage: ''
      });
    } catch (error) {
      this.setData({ errorMessage: '设置页资料加载失败，请重试' });
    } finally {
      this.setData({ loading: false });
    }
  },

  navigateTo(event) {
    const url = event.currentTarget.dataset.url;
    if (url) {
      wx.navigateTo({ url });
    }
  },

  async handleLogout() {
    if (this.data.loggingOut) return;
    const isEn = this.data.currentLanguage === 'en';
    const { confirm } = await wx.showModal({
      title: this.data.t.logout || '确认退出',
      content: isEn 
        ? 'Are you sure you want to log out?' 
        : '退出后将无法接收通知和消息，确认退出登录吗？',
      confirmColor: '#FF3B30',
      confirmText: isEn ? 'Logout' : '确认',
      cancelText: isEn ? 'Cancel' : '取消'
    });
    if (!confirm) return;
    this.setData({ loggingOut: true });
    wx.showLoading({ title: isEn ? 'Logging out...' : '退出中' });
    try {
      await logout();
      clearLocalSession();
      wx.reLaunch({ url: '/pages/profile/index' });
    } catch (error) {
      wx.showToast({
        title: isEn ? 'Logout failed' : '退出失败，请重试',
        icon: 'none'
      });
    } finally {
      wx.hideLoading();
      this.setData({ loggingOut: false });
    }
  }
});
