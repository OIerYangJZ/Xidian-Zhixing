import { sendCode, verifyEmail } from '../../../api/auth';
import { clearCampusAuthSession } from '../../../utils/campus_auth';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const EMAIL_SUFFIX = '@stu.xidian.edu.cn';

Page({
  onShow() {
    applyThemeAndLanguage(this);
  },
  data: {
    studentId: '',
    emailSuffix: EMAIL_SUFFIX,
    code: '',
    sendingCode: false,
    verifying: false,
    codeSent: false
  },

  onLoad(options) {
    const email = options.email ? decodeURIComponent(options.email) : '';
    this.setData({
      studentId: email ? email.split('@')[0] : '',
      codeSent: Boolean(options.email)
    });
  },

  onStudentIdInput(event) {
    this.setData({ studentId: event.detail.value });
  },

  onCodeInput(event) {
    this.setData({ code: event.detail.value });
  },

  buildEmail() {
    const studentId = this.data.studentId.trim();
    return studentId ? `${studentId}${EMAIL_SUFFIX}` : '';
  },

  async submitSendCode() {
    if (this.data.sendingCode) return;
    const email = this.buildEmail();
    if (!email) {
      wx.showToast({ title: '请输入学号', icon: 'none' });
      return;
    }
    this.setData({ sendingCode: true });
    wx.showLoading({ title: '发送中' });
    try {
      await sendCode(email);
      wx.hideLoading();
      this.setData({
        sendingCode: false,
        codeSent: true
      });
      wx.showToast({ title: '验证码已发送', icon: 'success' });
    } catch (error) {
      wx.hideLoading();
      this.setData({ sendingCode: false });
    }
  },

  async submitVerify() {
    if (this.data.verifying) return;
    const email = this.buildEmail();
    const code = this.data.code.trim();
    if (!email || code.length !== 6) {
      wx.showToast({ title: '请输入 6 位验证码', icon: 'none' });
      return;
    }
    this.setData({ verifying: true });
    wx.showLoading({ title: '验证中' });
    try {
      const res = await verifyEmail(email, code);
      clearCampusAuthSession();
      wx.setStorageSync('token', res.data.token);
      wx.showToast({ title: '已登录', icon: 'success' });
      setTimeout(() => wx.switchTab({ url: '/pages/treehole/index' }), 700);
    } catch (error) {
      wx.showToast({
        title: (error && error.data && error.data.message) || '验证码错误或已过期',
        icon: 'none'
      });
    } finally {
      wx.hideLoading();
      this.setData({ verifying: false });
    }
  }
});
