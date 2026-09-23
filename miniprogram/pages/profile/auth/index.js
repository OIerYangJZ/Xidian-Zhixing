import {
  createXidianAuthSession,
  fetchXidianAuthSession
} from '../../../api/auth';
import { clearCampusAuthSession } from '../../../utils/campus_auth';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  onShow() {
    applyThemeAndLanguage(this);
    if (this._awaitingOfficialReturn) {
      this._awaitingOfficialReturn = false;
      this.checkAuthenticationResult();
    }
  },
  data: {
    attemptId: '',
    authorizeUrl: '',
    submitting: false
  },

  onLoad() {
    wx.setNavigationBarTitle({ title: '统一身份认证登录' });
  },

  async handleLogin() {
    const { submitting } = this.data;
    if (submitting) return;

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
      wx.showToast({ title: '登录成功', icon: 'success' });
      setTimeout(() => {
        wx.navigateBack({
          delta: 1,
          fail: () => wx.switchTab({ url: '/pages/treehole/index' })
        });
      }, 800);
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

  goTerms() {
    wx.navigateTo({ url: '/pages/profile/legal/index?type=user-agreement' });
  },

  goPrivacy() {
    wx.navigateTo({ url: '/pages/profile/legal/index?type=privacy-policy' });
  }
});
