import { enterPage } from '../../../utils/motion';
import { getUserInfo, logout } from '../../../api/auth';
import { clearLocalSession, requireLoginPage } from '../../../utils/auth_guard';
import { avatarInitial } from '../../../utils/format';
import { applyThemeAndLanguage, getDisplayMode } from '../../../utils/theme_i18n';
import { setLanguage } from '../../../utils/i18n';
import { settingsText } from '../../../utils/settings_copy';

Page({
  data: { loading: true, loggingOut: false, userInfo: null, errorMessage: '', preferenceMessage: '', preferenceError: false, c: {}, currentModeOption: 'system', languageIndex: 0, languages: ['简体中文', 'English'], modeOptions: [] },
  onShow() {
    enterPage(this);
    this.refreshPreferences();
    if (!requireLoginPage()) return;
    const token = wx.getStorageSync('token');
    if (this._token !== token) {
      this._token = token;
      this.setData({userInfo:null,errorMessage:''});
    }
    this.fetchUserInfo();
  },
  onUnload() { this._loadId = (this._loadId || 0) + 1; },
  refreshPreferences() {
    applyThemeAndLanguage(this);
    const c = settingsText(this.data.currentLanguage);
    this.setData({
      c, currentModeOption: getDisplayMode(), languageIndex: this.data.currentLanguage === 'en' ? 1 : 0,
      modeOptions: [{value:'system',label:c.system},{value:'light',label:c.light},{value:'dark',label:c.dark}]
    });
  },
  async fetchUserInfo() {
    const id = this._loadId = (this._loadId || 0) + 1;
    const token = wx.getStorageSync('token');
    this.setData({ loading: true, errorMessage: '' });
    try {
      const response = await getUserInfo();
      if (id !== this._loadId || token !== wx.getStorageSync('token')) return;
      if (!response.data.id) throw new Error(this.data.c.loadFailed);
      const user = response.data;
      this.setData({userInfo:{...user,avatarInitial:avatarInitial(user.nickname || user.alias)},loading:false});
    } catch (error) {
      if (id === this._loadId && token === wx.getStorageSync('token')) this.setData({loading:false,errorMessage:this.data.c.loadFailed});
    }
  },
  onModeTap(event) {
    const mode = event.currentTarget.dataset.mode;
    if (!['system','light','dark'].includes(mode) || mode === this.data.currentModeOption) return;
    try {
      wx.setStorageSync('displayMode',mode);
      this.refreshPreferences();
      this.setData({preferenceMessage:this.data.c.saved,preferenceError:false});
    } catch (error) {
      this.setData({preferenceMessage:this.data.currentLanguage === 'en' ? 'Could not apply the change. Please try again.' : '未能应用更改，请重试。',preferenceError:true});
    }
  },
  onLanguageChange(event) {
    const index = Number(event.detail.value);
    if (![0,1].includes(index) || index === this.data.languageIndex) return;
    try {
      setLanguage(index === 1 ? 'en' : 'zh-CN');
      this.refreshPreferences();
      this.setData({preferenceMessage:this.data.c.saved,preferenceError:false});
    } catch (error) {
      this.setData({preferenceMessage:this.data.currentLanguage === 'en' ? 'Could not apply the change. Please try again.' : '未能应用更改，请重试。',preferenceError:true});
    }
  },
  navigateTo(event) {
    if (this.data.loggingOut) return;
    const url = event.currentTarget.dataset.url;
    if (url) wx.navigateTo({url});
  },
  async handleLogout() {
    if (this.data.loggingOut) return;
    const token = wx.getStorageSync('token');
    this.setData({loggingOut:true,logoutError:''});
    try {
      const result = await wx.showModal({title:this.data.c.logoutTitle,content:this.data.c.logoutCopy,confirmText:this.data.c.logout,cancelText:this.data.c.cancel});
      if (!result.confirm || token !== wx.getStorageSync('token')) return;
      await logout();
      if (token !== wx.getStorageSync('token')) return;
      clearLocalSession();
      wx.reLaunch({url:'/pages/profile/auth/index'});
    } catch (error) {
      this.setData({logoutError:this.data.currentLanguage === 'en' ? 'Unable to log out. Please try again.' : '退出失败，请重试。'});
    } finally {
      this.setData({loggingOut:false});
    }
  }
});
