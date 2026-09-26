import { getUserInfo, logout } from '../../../api/auth';
import { getMyLatestAppeal, submitUnbanAppeal } from '../../../api/appeals';
import { clearLoginAndRedirect, requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const CONTENT_LIMIT = 4000;

// wx.request rejects with the response ({ statusCode, data }) or a fail object ({ errMsg }).
const errorText = (error) => (error && error.data && error.data.message)
  || (error && error.message)
  || (error && error.errMsg)
  || '网络异常';

// Where a banned session lands (handoff W9, as on the web): the account is
// signed in, but the server refuses everything except the profile and the
// appeal endpoints.
Page({
  data: {
    loading: true,
    errorMessage: '',
    // 'form' | 'pending' | 'email' | 'lifted'
    mode: '',
    appealContent: '',
    adminNote: '',
    supportEmail: '',
    content: '',
    contentLimit: CONTENT_LIMIT,
    submitting: false
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadState();
  },

  async loadState() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const state = await getMyLatestAppeal();
      const appeal = state.appeal || {};
      const status = String(appeal.status || '');
      let mode = 'email';
      if (!state.banned) mode = 'lifted';
      else if (status === 'pending') mode = 'pending';
      // One in-app appeal per ban, decided by the server; once this ban's
      // is turned down only the support mailbox remains.
      else if (state.canSubmit) mode = 'form';
      this.setData({
        loading: false,
        mode,
        appealContent: String(appeal.content || ''),
        adminNote: String(appeal.adminNote || ''),
        supportEmail: String(state.supportEmail || '')
      });
    } catch (error) {
      this.setData({ loading: false, errorMessage: errorText(error) });
    }
  },

  onContentInput(event) {
    this.setData({ content: event.detail.value });
  },

  async submitAppeal() {
    if (this.data.submitting) return;
    const content = this.data.content.trim();
    if (!content) {
      wx.showToast({ title: '请填写申诉说明', icon: 'none' });
      return;
    }
    this.setData({ submitting: true });
    try {
      // The appeal is filed under the campus address signed in with.
      const profile = (await getUserInfo()).data;
      await submitUnbanAppeal({ email: profile.email, content });
      this.setData({ content: '', submitting: false });
      wx.showToast({ title: '申诉已提交', icon: 'success' });
      this.loadState();
    } catch (error) {
      this.setData({ submitting: false });
      wx.showToast({ title: errorText(error), icon: 'none' });
      // e.g. 409 本次封禁的站内申诉已用完: show the mailbox instead.
      if (error && error.statusCode === 409) this.loadState();
    }
  },

  copySupportEmail() {
    wx.setClipboardData({ data: this.data.supportEmail });
  },

  enterApp() {
    wx.reLaunch({ url: '/pages/treehole/index' });
  },

  // Signing out never keeps the user here: the server drops the token when
  // it can (logout needs no live session), and the local one goes either way.
  async signOut() {
    try {
      await logout();
    } catch (error) {
      console.error(error);
    }
    clearLoginAndRedirect();
  }
});
