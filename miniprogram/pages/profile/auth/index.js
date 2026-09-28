import {
  createXidianAuthSession,
  fetchXidianAuthSession
} from '../../../api/auth';
import { clearCampusAuthSession } from '../../../utils/campus_auth';
import { isTabRoute } from '../../../utils/navigation';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  onShow() {
    const app = getApp();
    this.setData({ navTop: app.globalData.navTop || 44, navHeight: app.globalData.navHeight || 32 });
    applyThemeAndLanguage(this);
    if (this._awaitingOfficialReturn) {
      this._awaitingOfficialReturn = false;
      this.checkAuthenticationResult();
    }
  },
  data: {
    attemptId: '',
    authorizeUrl: '',
    submitting: false,
    // Consent has to be given explicitly before signing in.
    agreed: false,
    agreementHint: false,
    // Bumped per attempt without consent, to replay the shake.
    nudge: 0,
    // Handoff L1: from a shared link, say what opens after signing in.
    sharedKind: '',
    navTop: 44,
    navHeight: 32
  },

  toggleAgreement() {
    this.setData({ agreed: !this.data.agreed, agreementHint: false });
  },

  onLoad(options = {}) {
    let redirect = '';
    try {
      redirect = decodeURIComponent(options.redirect || '');
    } catch (error) {
      redirect = '';
    }
    // Only in-app pages; anything else falls back to navigateBack.
    this._redirect = /^\/pages\//.test(redirect) ? redirect : '';
    this.setData({
      sharedKind: this._redirect.startsWith('/pages/campus/post-detail')
        ? 'post'
        : (this._redirect.startsWith('/pages/profile/public-user') ? 'profile' : '')
    });
  },

  returnAfterLogin() {
    if (this._redirect) {
      if (isTabRoute(this._redirect)) {
        wx.switchTab({ url: this._redirect.split('?')[0] });
      } else {
        wx.redirectTo({ url: this._redirect });
      }
      return;
    }
    wx.navigateBack({
      delta: 1,
      fail: () => wx.switchTab({ url: '/pages/treehole/index' })
    });
  },

  async handleLogin() {
    const { submitting } = this.data;
    if (submitting) return;
    if (!this.data.agreed) {
      // Drop and re-add the hint so the shake replays on every tap.
      this.setData({ agreementHint: false }, () => {
        setTimeout(() => this.setData({ agreementHint: true }), 16);
      });
      return;
    }

    this.setData({ submitting: true });
    wx.showLoading({ title: '正在跳转' });
    try {
      let { attemptId, authorizeUrl } = this.data;
      if (!attemptId || !authorizeUrl) {
        const response = await createXidianAuthSession();
        attemptId = response.data.attemptId;
        authorizeUrl = response.data.authorizeUrl;
        this.setData({ attemptId, authorizeUrl });
      }
      this._awaitingOfficialReturn = true;
      wx.navigateTo({
        url: `/pages/campus/webview/index?url=${encodeURIComponent(authorizeUrl)}`,
        fail: (error) => {
          this._awaitingOfficialReturn = false;
          this.setData({ submitting: false });
          wx.showToast({
            title: (error && error.errMsg) || '无法打开官方认证页面',
            icon: 'none'
          });
        }
      });
    } catch (err) {
      console.error(err);
      wx.showToast({
        title: (err && err.data && err.data.message) || err.message || '统一认证登录失败',
        icon: 'none'
      });
    } finally {
      wx.hideLoading();
      this.setData({ submitting: false });
    }
  },

  async checkAuthenticationResult() {
    const { attemptId } = this.data;
    if (!attemptId || this._checkingSession) return;
    this._checkingSession = true;
    this.setData({ submitting: true });
    wx.showLoading({ title: '确认认证结果' });
    try {
      const response = await fetchXidianAuthSession(attemptId);
      const data = response.data;
      if (data.status === 'pending') {
        wx.showToast({ title: '认证尚未完成，可重新打开官方页面', icon: 'none' });
        return;
      }
      if (data.status === 'failed') {
        throw new Error(data.message || '统一认证登录失败');
      }
      clearCampusAuthSession();
      wx.setStorageSync('token', data.token);
      this.setData({ attemptId: '', authorizeUrl: '' });
      if (data.banned) {
        // Every page but the appeal one would be refused.
        wx.reLaunch({ url: '/pages/profile/appeal/index' });
        return;
      }
      wx.showToast({ title: '登录成功', icon: 'success' });
      setTimeout(() => this.returnAfterLogin(), 800);
    } catch (err) {
      console.error(err);
      this.setData({ attemptId: '', authorizeUrl: '' });
      wx.showToast({
        title: (err && err.data && err.data.message) || err.message || '统一认证登录失败',
        icon: 'none'
      });
    } finally {
      wx.hideLoading();
      this._checkingSession = false;
      this.setData({ submitting: false });
    }
  },

  goAdminLogin() {
    wx.navigateTo({ url: '/pages/admin/login/index' });
  },

  goTerms() {
    wx.navigateTo({ url: '/pages/profile/legal/index?type=user-agreement' });
  },

  goPrivacy() {
    wx.navigateTo({ url: '/pages/profile/legal/index?type=privacy-policy' });
  }
});
