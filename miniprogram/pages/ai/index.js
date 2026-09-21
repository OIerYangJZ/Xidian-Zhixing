import { formatTime, truncate } from '../../utils/format';
import { getUserInfo } from '../../api/auth';
import { requireLoginPage } from '../../utils/auth_guard';
import { fetchAiModels } from '../../api/ai';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';
import { avatarInitial } from '../../utils/format';

Page({
  data: {
    history: [],
    draft: '',
    configured: false,
    currentModel: '',
    subtitleText: '正在读取 AI 状态',
    configError: '',
    drawerOpen: false,
    touchStartX: 0,
    touchStartY: 0,
    navTop: 0,
    navHeight: 48,
    userInfo: null,
    userErrorMessage: ''
  },

  onLoad() {
    this.initCustomNav();
    setTimeout(() => {
      if (!requireLoginPage()) return;
      this.loadUserInfo();
      this.loadHistory();
    }, 0);
  },

  onShow() {
    applyThemeAndLanguage(this);
    this.initCustomNav();
    setTimeout(() => {
      applyThemeAndLanguage(this);
      if (!requireLoginPage()) return;
      this.loadUserInfo();
      this.loadHistory();
    }, 0);
  },

  initCustomNav() {
    const app = getApp();
    this.setData({
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32
    });
  },

  async loadHistory() {
    const rows = (wx.getStorageSync('aiHistory') || []).slice(0, 5).map((item) => ({
      id: item.createdAt || item.question,
      title: truncate(item.question, 28),
      date: formatTime(item.createdAt),
      question: item.question
    }));
    this.setData({
      history: rows,
      configured: false,
      currentModel: '',
      subtitleText: '正在读取 AI 状态',
      configError: ''
    });
    try {
      const status = await fetchAiModels();
      this.setData({
        configured: Boolean(status.configured),
        currentModel: status.model || '',
        subtitleText: status.configured ? `当前模型：${status.model}` : 'AI 尚未启用',
        configError: ''
      });
    } catch (error) {
      this.setData({
        configured: false,
        currentModel: '',
        subtitleText: 'AI 状态加载失败',
        configError: 'AI 状态加载失败，请重试'
      });
    }
  },

  async loadUserInfo() {
    this.setData({ userErrorMessage: '' });
    try {
      const response = await getUserInfo();
      const user = response.data || {};
      this.setData({
        userInfo: {
          ...user,
          avatarInitial: avatarInitial(user.nickname || user.alias || user.email)
        }
      });
    } catch (error) {
      this.setData({
        userErrorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '用户信息加载失败，请重试'
      });
    }
  },

  retryLoadUserInfo() {
    this.loadUserInfo();
  },

  retryLoadAiStatus() {
    this.loadHistory();
  },

  onDraftInput(event) { this.setData({ draft: event.detail.value }); },

  submitQuestion() {
    const question = this.data.draft.trim();
    if (!question || !this.data.configured || !requireLoginPage()) return;
    wx.navigateTo({ url: `/pages/ai/chat/index?prefill=${encodeURIComponent(question)}` });
    this.setData({ draft: '' });
  },

  startNewChat() {
    if (!requireLoginPage()) return;
    wx.navigateTo({
      url: '/pages/ai/chat/index'
    });
  },

  continueChat(e) {
    if (!requireLoginPage()) return;
    const id = e.currentTarget.dataset.id;
    const question = e.currentTarget.dataset.question || '';
    wx.navigateTo({
      url: `/pages/ai/chat/index?id=${encodeURIComponent(id)}&q=${encodeURIComponent(question)}`
    });
  },

  goToHistory() {
    if (!requireLoginPage()) return;
    wx.navigateTo({
      url: '/pages/ai/history/index'
    });
  },

  goToSettings() {
    if (!requireLoginPage()) return;
    wx.navigateTo({
      url: '/pages/profile/ai-settings/index'
    });
  },

  openDrawer() {
    this.setData({ drawerOpen: true });
  },

  closeDrawer() {
    this.setData({ drawerOpen: false });
  },

  onTouchStart(event) {
    const touch = event.touches && event.touches[0];
    if (!touch) return;
    this.setData({ touchStartX: touch.clientX, touchStartY: touch.clientY });
  },

  onTouchEnd(event) {
    const touch = event.changedTouches && event.changedTouches[0];
    if (!touch) return;
    const deltaX = touch.clientX - this.data.touchStartX;
    const deltaY = Math.abs(touch.clientY - this.data.touchStartY);
    if (this.data.touchStartX < 24 && deltaX > 70 && deltaY < 50) this.openDrawer();
  }
});
