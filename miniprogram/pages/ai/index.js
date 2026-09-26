import { formatTime, truncate } from '../../utils/format';
import { getUserInfo } from '../../api/auth';
import { requireLoginPage } from '../../utils/auth_guard';
import { fetchAiModels } from '../../api/ai';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';
import { avatarInitial } from '../../utils/format';

Page({
  data: {
    examples: ['图书馆几点闭馆？', '怎么申请缓考？', '南校区哪里能打印？'],
    statusLoaded: false,
    history: [],
    configured: false,
    currentModel: '',
    subtitleText: '正在读取服务器 AI 状态',
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
      title: truncate(item.title || item.question, 28),
      date: formatTime(item.createdAt),
      createdAt: item.createdAt || '',
      question: item.question
    }));
    this.setData({
      history: rows,
      configured: false,
      currentModel: '',
      subtitleText: '正在读取服务器 AI 状态',
      configError: ''
    });
    try {
      const status = await fetchAiModels();
      this.setData({
        statusLoaded: true,
        configured: Boolean(status.configured),
        currentModel: status.model || '',
        subtitleText: status.configured ? `当前模型：${status.model}` : '服务器 AI 尚未配置',
        configError: ''
      });
    } catch (error) {
      this.setData({
        statusLoaded: true,
        configured: false,
        currentModel: '',
        subtitleText: '服务器 AI 状态加载失败',
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

  startNewChat() {
    if (!requireLoginPage()) return;
    wx.navigateTo({
      url: '/pages/ai/chat/index'
    });
  },

  continueChat(e) {
    if (!requireLoginPage()) return;
    const { createdAt, question } = e.currentTarget.dataset;
    // A saved chat opens with its answer, the same as from 问答历史;
    // an entry without a timestamp has nothing to restore and asks again.
    wx.navigateTo({
      url: createdAt
        ? `/pages/ai/chat/index?historyAt=${encodeURIComponent(createdAt)}`
        : `/pages/ai/chat/index?q=${encodeURIComponent(question || '')}`
    });
  },

  // 可以这样问: opens a chat with the question; it sends itself when the
  // server has AI configured.
  askExample(e) {
    if (!requireLoginPage()) return;
    const q = e.currentTarget.dataset.q || '';
    wx.navigateTo({ url: `/pages/ai/chat/index?q=${encodeURIComponent(q)}` });
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
