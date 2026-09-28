import { adminLogin } from '../../../api/admin';
import { ADMIN_CONSOLE_PAGE, getAdminToken, setAdminSession } from '../../../utils/admin_session';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

// 管理员登录: an administrator account (username + password), separate from
// student accounts.  It needs no student sign-in, so school staff without a
// student account can use it, and a student who is also an administrator
// stays signed in as a student.
Page({
  data: {
    username: '',
    password: '',
    submitting: false,
    errorMessage: ''
  },

  onLoad() {
    // Already signed in as an administrator: straight to the console.
    if (getAdminToken()) wx.redirectTo({ url: ADMIN_CONSOLE_PAGE });
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  onUsernameInput(event) {
    this.setData({ username: event.detail.value, errorMessage: '' });
  },

  onPasswordInput(event) {
    this.setData({ password: event.detail.value, errorMessage: '' });
  },

  async submit() {
    const username = this.data.username.trim();
    const password = this.data.password;
    if (!username || !password) {
      this.setData({ errorMessage: '请输入管理员账号和密码' });
      return;
    }
    if (this.data.submitting) return;
    this.setData({ submitting: true, errorMessage: '' });
    try {
      const data = await adminLogin(username, password);
      setAdminSession(data.token, {
        username: data.username,
        role: data.role,
        roleLabel: data.roleLabel,
        isPrimary: Boolean(data.isPrimary)
      });
      this.setData({ password: '' });
      wx.redirectTo({ url: ADMIN_CONSOLE_PAGE });
    } catch (error) {
      this.setData({
        errorMessage: (error && error.data && error.data.message) || (error && error.message) || '登录失败，请重试'
      });
    } finally {
      this.setData({ submitting: false });
    }
  }
});
