import { login } from '../../../api/auth';
import { clearCampusAuthSession } from '../../../utils/campus_auth';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  onShow() {
    applyThemeAndLanguage(this);
  },
  data: {
    identifier: '',
    password: '',
    submitting: false
  },

  onLoad(options) {
    if (options && options.mode === 'xidian') {
      wx.redirectTo({
        url: '/pages/campus/auth-center/index?system=ids'
      });
      return;
    }
    wx.setNavigationBarTitle({ title: '电台账号登录' });
  },

  onIdentifierInput(e) {
    this.setData({ identifier: e.detail.value });
  },

  onPasswordInput(e) {
    this.setData({ password: e.detail.value });
  },

  async handleLogin() {
    const { identifier, password, submitting } = this.data;
    if (submitting) return;
    if (!identifier || !password) {
      wx.showToast({ title: '请输入账号和密码', icon: 'none' });
      return;
    }

    this.setData({ submitting: true });
    wx.showLoading({ title: '登录中' });
    try {
      const res = await login(identifier, password);
      if (res && res.data && res.data.token) {
        clearCampusAuthSession();
        wx.setStorageSync('token', res.data.token);
        wx.showToast({ title: '登录成功', icon: 'success' });
        setTimeout(() => {
          wx.navigateBack({
            delta: 1,
            fail: () => wx.switchTab({ url: '/pages/treehole/index' })
          });
        }, 1500);
      } else if (res && res.data && res.data.needVerify) {
        wx.showModal({
          title: '需要邮箱验证',
          content: '账号尚未完成邮箱验证，是否现在验证？',
          success: (modal) => {
            if (modal.confirm) {
              wx.navigateTo({
                url: `/pages/profile/register/index?email=${encodeURIComponent(res.data.email || '')}`
              });
            }
          }
        });
      }
    } catch (err) {
      console.error(err);
      wx.showToast({
        title: (err && err.data && err.data.message) || '登录失败，请检查账号和密码',
        icon: 'none'
      });
    } finally {
      wx.hideLoading();
      this.setData({ submitting: false });
    }
  },

  handleEmailCodeLogin() {
    wx.navigateTo({ url: '/pages/profile/register/index' });
  },

  handleResetPassword() {
    wx.navigateTo({ url: '/pages/profile/reset-password/index' });
  },

  goTerms() {
    wx.navigateTo({ url: '/pages/profile/legal/index?type=terms' });
  },

  goPrivacy() {
    wx.navigateTo({ url: '/pages/profile/legal/index?type=privacy' });
  }
});
