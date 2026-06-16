import { login, loginWithXidianPassword } from '../../../api/auth';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  onShow() {
    applyThemeAndLanguage(this);
  },
  data: {
    authMode: 'xidian',
    identifier: '',
    password: '',
    submitting: false
  },

  onLoad(options) {
    if (options && options.mode === 'xidian') {
      this.setData({ authMode: 'xidian' });
      wx.setNavigationBarTitle({ title: '西电统一认证' });
    }
  },

  switchAuthMode(e) {
    const mode = e.currentTarget.dataset.mode;
    if (!mode || mode === this.data.authMode) return;
    this.setData({ authMode: mode });
  },

  onIdentifierInput(e) {
    this.setData({ identifier: e.detail.value });
  },

  onPasswordInput(e) {
    this.setData({ password: e.detail.value });
  },

  async handleLogin() {
    const { authMode, identifier, password, submitting } = this.data;
    if (submitting) return;
    if (!identifier || !password) {
      wx.showToast({ title: authMode === 'xidian' ? '请输入学号和统一认证密码' : '请输入账号和密码', icon: 'none' });
      return;
    }

    this.setData({ submitting: true });
    wx.showLoading({ title: authMode === 'xidian' ? '统一认证中' : '登录中' });
    try {
      const res = authMode === 'xidian'
        ? await loginWithXidianPassword(identifier, password)
        : await login(identifier, password);
      wx.hideLoading();
      if (res && res.data && res.data.token) {
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
                url: `/pages/profile/register/index?email=${encodeURIComponent(res.data.email || '')}&debugCode=${encodeURIComponent(res.data.debugCode || '')}`
              });
            }
          }
        });
      }
    } catch (err) {
      wx.hideLoading();
      console.error(err);
    } finally {
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
