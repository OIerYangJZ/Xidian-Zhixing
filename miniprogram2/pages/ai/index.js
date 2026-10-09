import { enterPage, retainLayerExit, cancelLayerExit, clearLayerMotion } from '../../utils/motion';
import { fetchAiModels, sendAiMessage, deleteAiConversation } from '../../api/ai';
import { requireLoginPage } from '../../utils/auth_guard';
import { formatTime, truncate } from '../../utils/format';
import { openAppTarget } from '../../utils/navigation';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';
import { takePendingAiEntry } from '../../utils/ai_workspace';

const CONVERSATIONS_KEY = 'aiConversations';
const ACTIVE_CONVERSATION_KEY = 'activeAiConversationId';
const MAX_CONVERSATIONS = 30;

const normalizeAiReply = (response) => {
  const data = response && response.data ? response.data : response || {};
  return String(data.reply || data.answer || data.content || '').trim();
};

const normalizeReferences = (response) => {
  const data = response && response.data ? response.data : response || {};
  const rows = Array.isArray(data.citations)
    ? data.citations
    : (Array.isArray(data.references) ? data.references : []);
  return rows.map((item, index) => ({
    ...item,
    key: `${item.type || 'ref'}-${item.id || index}`,
    title: item.title || (item.type === 'post' || item.targetType === 'post' ? '相关帖子' : '基础资料')
  }));
};

const normalizeMessage = (message = {}, index = 0) => ({
  id: String(message.id || `message-${Date.now()}-${index}`),
  role: message.role === 'user' ? 'user' : 'assistant',
  content: String(message.content || ''),
  references: Array.isArray(message.references) ? message.references : []
});

const normalizeConversation = (conversation = {}, index = 0) => {
  const messages = Array.isArray(conversation.messages)
    ? conversation.messages.map(normalizeMessage).filter((item) => item.content)
    : [];
  const firstQuestion = messages.find((item) => item.role === 'user');
  return {
    id: String(conversation.id || conversation.createdAt || `chat-${Date.now()}-${index}`),
    title: truncate(conversation.title || (firstQuestion && firstQuestion.content) || '新对话', 30),
    createdAt: conversation.createdAt || new Date().toISOString(),
    updatedAt: conversation.updatedAt || conversation.createdAt || new Date().toISOString(),
    backendId: String(conversation.backendId || ''),
    messages
  };
};

const migrateLegacyHistory = () => {
  const existing = wx.getStorageSync(CONVERSATIONS_KEY);
  if (Array.isArray(existing) && existing.length) return existing.map(normalizeConversation);
  const legacy = wx.getStorageSync('aiHistory');
  if (!Array.isArray(legacy)) return [];
  const migrated = legacy.filter((item) => item && item.question).map((item, index) => normalizeConversation({
    id: item.createdAt || `legacy-${index}`,
    title: item.question,
    createdAt: item.createdAt,
    updatedAt: item.createdAt,
    messages: [
      { id: `legacy-user-${index}`, role: 'user', content: item.question },
      { id: `legacy-assistant-${index}`, role: 'assistant', content: item.answer || '', references: item.references || [] }
    ]
  }, index));
  if (migrated.length) wx.setStorageSync(CONVERSATIONS_KEY, migrated);
  return migrated;
};

const buildConversationRows = (conversations) => conversations.map((item) => ({
  ...item,
  dateText: formatTime(item.updatedAt)
}));

Page({
  data: {
    conversations: [],
    activeConversationId: '',
    activeConversationTitle: '知行助手',
    messages: [],
    draft: '',
    isSending: false,
    scrollTop: 0,
    sidebarOpen: false,
    conversationMenuOpen: false,
    conversationMenuMode: 'actions',
    selectedConversationId: '',
    selectedConversationTitle: '',
    renameDraft: '',
    configured: false,
    currentModel: '',
    configLoading: true,
    configError: '',
    navTop: 0,
    navHeight: 48,
    navRight: 96,
    sidebarCloseRight: 12,
    touchStartX: 0,
    touchStartY: 0
  },

  onLoad() {
    applyThemeAndLanguage(this);
    this.initCustomNav();
    if (!requireLoginPage()) return;
    this.loadConversations();
    this.consumePendingEntry();
    this.refreshConfigState();
  },

  onShow() {
    enterPage(this, { animate: false });
    applyThemeAndLanguage(this);
    this.initCustomNav();
    if (!requireLoginPage()) return;
    if (!this.data.isSending) this.loadConversations(true);
    this.consumePendingEntry();
    this.refreshConfigState();
  },

  initCustomNav() {
    const app = getApp();
    const width = wx.getWindowInfo().windowWidth;
    this.setData({
      sidebarCloseRight: Math.max(12, Math.min(width * .84, 330) - (width - app.globalData.navRight)),
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32,
      navRight: app.globalData.navRight || 96
    });
  },

  syncOverlayTabBar() {
    if (typeof this.getTabBar !== 'function') return;
    const bar = this.getTabBar();
    if (bar) bar.setData({ modalHidden: this.data.sidebarOpen || this.data.conversationMenuOpen });
  },

  onHide() { this.closeSidebar(); clearLayerMotion(this); },
  onUnload() { this.closeSidebar(); clearLayerMotion(this); },

  loadConversations(preserveCurrent = false) {
    const conversations = migrateLegacyHistory()
      .sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)))
      .slice(0, MAX_CONVERSATIONS);
    const storedActiveId = wx.getStorageSync(ACTIVE_CONVERSATION_KEY) || '';
    const activeId = preserveCurrent && this.data.activeConversationId
      ? this.data.activeConversationId
      : storedActiveId;
    const active = conversations.find((item) => item.id === activeId);
    this._backendConversationId = active ? active.backendId || '' : '';
    this.setData({
      conversations: buildConversationRows(conversations),
      activeConversationId: active ? active.id : '',
      activeConversationTitle: active ? active.title : '知行助手',
      messages: active ? active.messages : (preserveCurrent ? this.data.messages : [])
    }, () => {
      if (active) this.scrollToBottom();
    });
  },

  consumePendingEntry() {
    const entry = takePendingAiEntry();
    if (!entry) return;
    wx.removeStorageSync(ACTIVE_CONVERSATION_KEY);
    this._backendConversationId = '';
    const answer = String(entry.answer || '').trim();
    this.setData({
      activeConversationId: '',
      activeConversationTitle: entry.title || '知行助手',
      messages: answer ? [{ id: `shared-answer-${Date.now()}`, role: 'assistant', content: answer, references: [] }] : [],
      draft: String(entry.prompt || ''),
      sidebarOpen: false,
      scrollTop: 0
    });
  },

  async refreshConfigState() {
    this.setData({ configLoading: true, configError: '' });
    try {
      const status = await fetchAiModels();
      this.setData({
        configured: Boolean(status.configured),
        currentModel: status.model || '',
        configLoading: false,
        configError: ''
      });
    } catch (error) {
      this.setData({ configured: false, currentModel: '', configLoading: false, configError: 'AI 状态加载失败，请重试' });
    }
  },

  toggleSidebar() {
    if (this.data.sidebarOpen) { this.closeSidebar(); return; }
    cancelLayerExit(this, 'sidebarOpen');
    this.setData({ sidebarOpen: true });
    this.syncOverlayTabBar();
  },

  closeSidebar() {
    retainLayerExit(this, 'sidebarOpen');
    this.closeConversationMenu();
    this.setData({ sidebarOpen: false });
    this.syncOverlayTabBar();
  },

  stopTap() {},

  startNewChat() {
    if (this.data.isSending) {
      wx.showToast({ title: '请等待当前回复完成', icon: 'none' });
      return;
    }
    wx.removeStorageSync(ACTIVE_CONVERSATION_KEY);
    this._backendConversationId = '';
    this.closeSidebar();
    this.setData({
      activeConversationId: '',
      activeConversationTitle: '知行助手',
      messages: [],
      draft: '',
      sidebarOpen: false,
      scrollTop: 0
    });
    this.syncOverlayTabBar();
  },

  selectConversation(event) {
    if (this._ignoreConversationTap) return;
    if (this.data.isSending) return;
    const id = String(event.currentTarget.dataset.id || '');
    const conversation = this.data.conversations.find((item) => item.id === id);
    if (!conversation) return;
    this._backendConversationId = conversation.backendId || '';
    wx.setStorageSync(ACTIVE_CONVERSATION_KEY, id);
    this.closeSidebar();
    this.setData({
      activeConversationId: id,
      activeConversationTitle: conversation.title,
      messages: conversation.messages,
      draft: '',
      sidebarOpen: false
    }, this.scrollToBottom);
    this.syncOverlayTabBar();
  },

  openConversationMenu(event) {
    const id = String(event.currentTarget.dataset.id || '');
    const conversation = this.data.conversations.find((item) => item.id === id);
    if (!conversation) return;
    cancelLayerExit(this, 'conversationMenuOpen');
    this._ignoreConversationTap = true;
    setTimeout(() => { this._ignoreConversationTap = false; }, 350);
    this.setData({
      conversationMenuOpen: true,
      conversationMenuMode: 'actions',
      selectedConversationId: id,
      selectedConversationTitle: conversation.title,
      renameDraft: conversation.title
    });
    this.syncOverlayTabBar();
  },

  closeConversationMenu() {
    retainLayerExit(this, 'conversationMenuOpen', () => {
      this.setData({ conversationMenuMode: 'actions', selectedConversationId: '', selectedConversationTitle: '', renameDraft: '' });
    });
    this.setData({ conversationMenuOpen: false });
    this.syncOverlayTabBar();
  },

  beginRenameConversation() {
    this.setData({ conversationMenuMode: 'rename' });
  },

  onRenameInput(event) {
    this.setData({ renameDraft: event.detail.value });
  },

  saveConversationName() {
    const id = this.data.selectedConversationId;
    const title = this.data.renameDraft.trim().slice(0, 40);
    if (!id || !title) return;
    const conversations = this.data.conversations.map((item) => (
      item.id === id ? { ...item, title, updatedAt: new Date().toISOString() } : item
    ));
    wx.setStorageSync(CONVERSATIONS_KEY, conversations);
    this.setData({
      conversations: buildConversationRows(conversations),
      activeConversationTitle: this.data.activeConversationId === id ? title : this.data.activeConversationTitle
    });
    this.closeConversationMenu();
  },

  beginDeleteConversation() {
    this.setData({ conversationMenuMode: 'delete' });
  },

  async confirmDeleteConversation() {
    const id = this.data.selectedConversationId;
    if (!id) return;
    const conversation = this.data.conversations.find((item) => item.id === id);
    // The local list is only a cache: the answer history lives in the server conversation that
    // `backendId` points at, so dropping the cache alone would leave it there forever.
    const backendId = conversation ? conversation.backendId : '';
    if (backendId) {
      wx.showLoading({ title: '正在删除', mask: true });
      try {
        await deleteAiConversation(backendId);
      } catch (error) {
        wx.hideLoading();
        wx.showToast({ title: '服务器删除失败，请重试', icon: 'none' });
        return;
      }
      wx.hideLoading();
    }
    const conversations = this.data.conversations.filter((item) => item.id !== id);
    wx.setStorageSync(CONVERSATIONS_KEY, conversations);
    if (id === this.data.activeConversationId) {
      wx.removeStorageSync(ACTIVE_CONVERSATION_KEY);
      this._backendConversationId = '';
      this.setData({
        conversations: buildConversationRows(conversations),
        activeConversationId: '',
        activeConversationTitle: '知行助手',
        messages: [],
        draft: ''
      });
      this.closeConversationMenu();
      return;
    }
    this.setData({ conversations: buildConversationRows(conversations) });
    this.closeConversationMenu();
  },

  persistConversation(messages) {
    const now = new Date().toISOString();
    const firstQuestion = messages.find((item) => item.role === 'user');
    const id = this.data.activeConversationId || `chat-${Date.now()}`;
    const previous = this.data.conversations.find((item) => item.id === id);
    const conversation = normalizeConversation({
      id,
      title: (previous && previous.title) || (firstQuestion && firstQuestion.content) || '新对话',
      createdAt: (previous && previous.createdAt) || now,
      updatedAt: now,
      backendId: this._backendConversationId || (previous && previous.backendId) || '',
      messages
    });
    const conversations = [conversation, ...this.data.conversations.filter((item) => item.id !== id)].slice(0, MAX_CONVERSATIONS);
    wx.setStorageSync(CONVERSATIONS_KEY, conversations);
    wx.setStorageSync(ACTIVE_CONVERSATION_KEY, id);
    this.setData({
      conversations: buildConversationRows(conversations),
      activeConversationId: id,
      activeConversationTitle: conversation.title
    });
  },

  onDraftInput(event) {
    this.setData({ draft: event.detail.value });
  },

  onSuggestionTap(event) {
    this.setData({ draft: event.currentTarget.dataset.value || '' });
  },

  submitQuestion() {
    return this.sendMessage();
  },

  async sendMessage() {
    const text = this.data.draft.trim();
    if (!text || this.data.isSending || !requireLoginPage()) return;

    const previousMessages = this.data.messages.slice();
    const userMessage = { id: `user-${Date.now()}`, role: 'user', content: text, references: [] };
    const pendingMessages = [...previousMessages, userMessage];
    this.setData({ messages: pendingMessages, draft: '', isSending: true }, this.scrollToBottom);
    this.persistConversation(pendingMessages);

    try {
      const response = await sendAiMessage(text, {
        conversationId: this._backendConversationId,
        language: wx.getStorageSync('language') === 'en' ? 'en' : 'zh'
      });
      const responseData = response && response.data ? response.data : response || {};
      if (responseData.conversationId) this._backendConversationId = String(responseData.conversationId);
      const reply = normalizeAiReply(response);
      if (!reply) throw new Error('AI response is empty');
      const assistantMessage = {
        id: `assistant-${Date.now()}`,
        role: 'assistant',
        content: reply,
        references: normalizeReferences(response)
      };
      const completedMessages = [...this.data.messages, assistantMessage];
      this.setData({ messages: completedMessages }, this.scrollToBottom);
      this.persistConversation(completedMessages);
    } catch (error) {
      const failureMessage = error?.data?.message || error?.data?.error || error?.message || '本次请求失败，请稍后重试。';
      const failedMessages = [...this.data.messages, {
        id: `error-${Date.now()}`,
        role: 'assistant',
        content: failureMessage,
        references: []
      }];
      this.setData({ messages: failedMessages, draft: this.data.draft || text }, this.scrollToBottom);
      this.persistConversation(failedMessages);
      wx.showToast({ title: failureMessage.slice(0, 20), icon: 'none' });
    } finally {
      this.setData({ isSending: false });
    }
  },

  scrollToBottom() {
    wx.createSelectorQuery().select('.ai-chat-list').boundingClientRect((rect) => {
      if (rect) this.setData({ scrollTop: rect.height + 9999 });
    }).exec();
  },

  openReference(event) {
    const messageIndex = Number(event.currentTarget.dataset.messageIndex);
    const referenceIndex = Number(event.currentTarget.dataset.referenceIndex);
    const message = this.data.messages[messageIndex];
    const reference = message && message.references ? message.references[referenceIndex] : null;
    if (!reference) return;
    if (!openAppTarget({ ...reference, url: reference.sourceUrl })) {
      wx.showToast({ title: '该来源暂无可打开页面', icon: 'none' });
    }
  },

  goToSettings() {
    wx.navigateTo({ url: '/pages/profile/ai-settings/index' });
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
    if (!this.data.sidebarOpen && this.data.touchStartX < 24 && deltaX > 70 && deltaY < 50) {
      cancelLayerExit(this, 'sidebarOpen');
      this.setData({ sidebarOpen: true });
      this.syncOverlayTabBar();
    }
  }
});
