import { enterPage } from '../../../utils/motion';
import { createLocalTestSession, createXidianAuthSession, fetchXidianAuthSession } from '../../../api/auth';
import { clearCampusAuthSession } from '../../../utils/campus_auth';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { envName } from '../../../config/env';

const LOCAL_TEST_LOGIN = envName === 'devtools' || envName === 'auto:devtools';

const PHASES = {
  idle: { stateTitle: '校园统一身份认证', stateMessage: '账号与密码仅在学校官方页面填写', buttonLabel: '使用校园账号登录', submitting: false },
  connecting: { stateTitle: '正在连接认证服务', stateMessage: '正在建立本次登录会话', buttonLabel: '正在连接', submitting: true },
  opening: { stateTitle: '正在打开官方认证', stateMessage: '认证完成后返回知行', buttonLabel: '正在打开', submitting: true },
  checking: { stateTitle: '正在确认校园身份', stateMessage: '正在获取本次认证结果', buttonLabel: '正在验证', submitting: true },
  pending: { stateTitle: '认证尚未完成', stateMessage: '可以继续认证，或重新检查认证结果', buttonLabel: '继续认证', submitting: false },
  success: { stateTitle: '认证成功', stateMessage: '正在进入知行', buttonLabel: '进入知行', submitting: true }
};

Page({
  data: {
    attemptId: '', authorizeUrl: '', phase: 'idle', ...PHASES.idle,
    errorMessage: '', retryAction: 'login', isLocalTestLogin: LOCAL_TEST_LOGIN,
    navTop: 44, navHeight: 32, navRight: 100, canGoBack: false
  },

  onLoad() {
    this._disposed = false;
    const { navTop, navHeight, navRight } = getApp().globalData;
    this.setData({
      navTop, navHeight, navRight,
      canGoBack: getCurrentPages().length > 1 && Boolean(wx.getStorageSync('token')),
      ...(LOCAL_TEST_LOGIN ? {
        stateTitle: '本地测试账号',
        stateMessage: '点击后直接进入本地测试账号',
        buttonLabel: '直接登录测试账号'
      } : {})
    });
  },

  onShow() {
    enterPage(this, { animate: false });
    applyThemeAndLanguage(this);
    if (this._awaitingOfficialReturn) {
      this._awaitingOfficialReturn = false;
      this.checkAuthenticationResult();
    }
  },

  onUnload() {
    this._disposed = true;
    clearTimeout(this._enterTimer);
  },

  setPhase(phase, update = {}) {
    if (this._disposed) return;
    this.setData({ phase, ...PHASES[phase], errorMessage: '', ...update });
  },

  showFailure(error, retryAction, message) {
    if (this._disposed) return;
    this.setData({
      phase: 'error', submitting: false, retryAction,
      stateTitle: retryAction === 'enter' ? '暂时无法进入页面' : '暂时无法完成登录',
      stateMessage: '',
      errorMessage: (error && error.data && error.data.message) || (error && (error.message || error.errMsg)) || message,
      buttonLabel: retryAction === 'check' ? '重新检查认证' : retryAction === 'enter' ? '重新进入' : '重试登录'
    });
  },

  handlePrimary() {
    if (this.data.submitting) return;
    if (this.data.phase === 'error' && this.data.retryAction === 'check') return this.checkAuthenticationResult();
    if (this.data.phase === 'error' && this.data.retryAction === 'enter') return this.enterCommunity();
    return this.handleLogin();
  },

  async handleLogin() {
    if (this.data.submitting || this._disposed) return;
    if (LOCAL_TEST_LOGIN) return this.handleLocalTestLogin();
    this.setPhase('connecting');
    try {
      let { attemptId, authorizeUrl } = this.data;
      if (!attemptId || !authorizeUrl) {
        const response = await createXidianAuthSession();
        if (this._disposed) return;
        ({ attemptId, authorizeUrl } = response.data);
        this.setData({ attemptId, authorizeUrl });
      }
      this.setPhase('opening');
      this._awaitingOfficialReturn = true;
      wx.navigateTo({
        url: `/pages/campus/webview/index?url=${encodeURIComponent(authorizeUrl)}`,
        fail: error => {
          this._awaitingOfficialReturn = false;
          this.showFailure(error, 'login', '无法打开官方认证页面，请重试');
        }
      });
    } catch (error) {
      this.showFailure(error, 'login', '连接失败，请检查网络后重试');
    }
  },

  async handleLocalTestLogin() {
    if (this.data.submitting || this._disposed) return;
    this.setPhase('connecting', {
      stateTitle: '正在登录本地测试账号',
      stateMessage: '',
      buttonLabel: '正在登录'
    });
    try {
      const response = await createLocalTestSession();
      if (this._disposed) return;
      const data = response.data;
      clearCampusAuthSession();
      wx.setStorageSync('token', data.token);
      wx.setStorageSync('userInfo', data.user);
      getApp().globalData.hasToken = true;
      this.setPhase('success');
      this._enterTimer = setTimeout(() => this.enterCommunity(), 360);
    } catch (error) {
      this.showFailure(error, 'login', '本地测试登录失败，请确认本地后端已启动');
    }
  },

  async checkAuthenticationResult() {
    if (!this.data.attemptId || this._checkingSession || this._disposed) return;
    this._checkingSession = true;
    this.setPhase('checking');
    try {
      const response = await fetchXidianAuthSession(this.data.attemptId);
      if (this._disposed) return;
      const data = response.data;
      if (data.status === 'pending') {
        this.setPhase('pending');
        return;
      }
      if (data.status === 'failed') {
        this.setData({ attemptId: '', authorizeUrl: '' });
        this.showFailure(new Error(data.message || '认证未通过，请重新登录'), 'login');
        return;
      }
      clearCampusAuthSession();
      wx.setStorageSync('token', data.token);
      if (data.user) wx.setStorageSync('userInfo', data.user);
      getApp().globalData.hasToken = true;
      this.setPhase('success', { attemptId: '', authorizeUrl: '' });
      this._enterTimer = setTimeout(() => this.enterCommunity(), 360);
    } catch (error) {
      if (this._disposed) return;
      if (error && error.statusCode === 404) {
        this.setData({ attemptId: '', authorizeUrl: '' });
        this.showFailure(error, 'login', '登录请求已过期，请重新登录');
      } else {
        this.showFailure(error, 'check', '认证结果读取失败，请重试');
      }
    } finally {
      this._checkingSession = false;
    }
  },

  enterCommunity() {
    if (this._disposed || this._entering) return;
    this._entering = true;
    this.setPhase('success');
    const callbacks = {
      success: () => { this._entering = false; },
      fail: error => {
        this._entering = false;
        this.showFailure(error, 'enter', '页面打开失败，请重试');
      }
    };
    if (getCurrentPages().length > 1) wx.navigateBack({ delta: 1, ...callbacks });
    else wx.switchTab({ url: '/pages/treehole/index', ...callbacks });
  },

  restartLogin() {
    if (this.data.submitting || this._disposed) return;
    this.setData({ attemptId: '', authorizeUrl: '' });
    return this.handleLogin();
  },

  goBack() { if (this.data.canGoBack) wx.navigateBack({ delta: 1 }); },
  goTerms() { if (!this.data.submitting) wx.navigateTo({ url: '/pages/profile/legal/index?type=user-agreement' }); },
  goPrivacy() { if (!this.data.submitting) wx.navigateTo({ url: '/pages/profile/legal/index?type=privacy-policy' }); }
});
