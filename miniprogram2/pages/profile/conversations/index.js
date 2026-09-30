import { enterPage, retainLayerExit, cancelLayerExit, clearLayerMotion } from '../../../utils/motion';
import { createDirectConversation, deleteConversation, getConversations } from '../../../api/messages';
import { searchUsers } from '../../../api/user';
import { formatTime, resolveUrl } from '../../../utils/format';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const REVEAL_WIDTH_RPX = 128;

Page({
  data: {
    navTop: 0,
    navHeight: 32,
    loading: true,
    refreshing: false,
    searchFocused: false,
    newMessageOpen: false,
    recipientKeyword: '',
    recipientLoading: false,
    recipientSearched: false,
    recipientError: '',
    recipients: [],
    creatingConversation: false,
    conversations: [],
    visibleConversations: [],
    searchKeyword: '',
    errorMessage: ''
  },

  onShow() {
    enterPage(this, { animate: false });
    this._openingChat = false;
    applyThemeAndLanguage(this);
    this.initLayout();
    if (!requireLoginPage()) return;
    this.loadData();
  },

  onHide() { this.closeNewMessage(); clearLayerMotion(this); },
  onUnload() { this._listRequest = (this._listRequest || 0) + 1; this.closeNewMessage(); clearLayerMotion(this); },

  openMessageSettings() {
    wx.navigateTo({ url: '/pages/profile/privacy/index' });
  },

  onSearchFocus() { this.setData({ searchFocused: true }); },
  onSearchBlur() { this.setData({ searchFocused: false }); },
  clearSearch() {
    this.setData({ searchKeyword: '', visibleConversations: this.applyConversationFilter(this.data.conversations, '') });
  },

  setPickerTabVisibility(hidden) {
    if (typeof this.getTabBar === 'function') {
      const bar = this.getTabBar();
      if (bar) bar.setData({ drawerHidden: hidden });
    }
  },

  openNewMessage() {
    cancelLayerExit(this, 'newMessageOpen');
    this.setData({ newMessageOpen: true, recipientKeyword: '', recipients: [], recipientError: '', recipientSearched: false });
    this.setPickerTabVisibility(true);
  },

  closeNewMessage() {
    retainLayerExit(this, 'newMessageOpen');
    this._recipientRequest = (this._recipientRequest || 0) + 1;
    this.setData({ newMessageOpen: false, recipientLoading: false });
    this.setPickerTabVisibility(false);
  },

  onRecipientInput(event) {
    this._recipientRequest = (this._recipientRequest || 0) + 1;
    this.setData({ recipientKeyword: event.detail.value, recipients: [], recipientSearched: false, recipientError: '', recipientLoading: false });
  },

  async searchRecipients() {
    const keyword = this.data.recipientKeyword.trim();
    if (!keyword || this.data.creatingConversation) return;
    const requestId = this._recipientRequest = (this._recipientRequest || 0) + 1;
    this.setData({ recipientLoading: true, recipientError: '', recipientSearched: true });
    try {
      const recipients = await searchUsers(keyword);
      if (requestId === this._recipientRequest) this.setData({ recipients });
    } catch (error) {
      if (requestId === this._recipientRequest) this.setData({ recipientError: error?.data?.message || error?.message || '搜索失败，请重试' });
    } finally {
      if (requestId === this._recipientRequest) this.setData({ recipientLoading: false });
    }
  },

  async startConversation(event) {
    const user = this.data.recipients[Number(event.currentTarget.dataset.index)];
    if (!user || this.data.creatingConversation) return;
    this.setData({ creatingConversation: true });
    try {
      const conversation = await createDirectConversation({ targetUserId: user.id });
      if (!conversation.id) throw new Error('会话创建失败');
      if (!this.data.newMessageOpen) return;
      this.closeNewMessage();
      wx.navigateTo({ url: `/pages/profile/chat/index?id=${encodeURIComponent(conversation.id)}&name=${encodeURIComponent(user.nickname)}&peerUserId=${encodeURIComponent(user.id)}&peerAvatar=${encodeURIComponent(user.avatarUrl || '')}` });
    } catch (error) {
      wx.showToast({ title: error?.data?.message || error?.message || '暂时无法发起私信', icon: 'none' });
    } finally {
      this.setData({ creatingConversation: false });
    }
  },

  initLayout() {
    const app = getApp();
    this.setData({
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32
    });
  },

  applyConversationFilter(conversations = this.data.conversations, keyword = this.data.searchKeyword) {
    const normalizedKeyword = String(keyword || '').trim().toLowerCase();
    return conversations
      .map((item, sourceIndex) => ({ ...item, sourceIndex }))
      .filter((item) => !normalizedKeyword
        || String(item.name || '').toLowerCase().includes(normalizedKeyword)
        || String(item.lastMessage || '').toLowerCase().includes(normalizedKeyword));
  },

  onSearchInput(event) {
    const searchKeyword = event.detail.value;
    this.setData({
      searchKeyword,
      visibleConversations: this.applyConversationFilter(this.data.conversations, searchKeyword)
    });
  },

  onPullDownRefresh() {
    this.loadData().finally(() => wx.stopPullDownRefresh());
  },

  async refreshList() {
    if (this.data.refreshing) return;
    this.setData({ refreshing: true });
    try { await this.loadData(); }
    finally { this.setData({ refreshing: false }); }
  },

  async loadData() {
    const account = wx.getStorageSync('token');
    if (account !== this._inboxAccount) {
      this._inboxAccount = account;
      this._hasLoaded = false;
      this.setData({ conversations: [], visibleConversations: [], searchKeyword: '' });
    }
    const request = this._listRequest = (this._listRequest || 0) + 1;
    this.setData({ loading: !this._hasLoaded, errorMessage: '' });
    try {
      const conversations = await getConversations();
      if (request !== this._listRequest || account !== wx.getStorageSync('token')) return;
      const normalized = conversations.map(item => ({
        ...item,
        avatarUrl: resolveUrl(item.avatarUrl || ''),
        timeText: item.updatedAt || /^\d{4}-/.test(item.timeText || '') ? formatTime(item.updatedAt || item.timeText) : item.timeText,
        offsetX: 0,
        avatarInitial: item.avatarInitial || item.name?.slice(0, 1) || '匿'
      }));
      this._hasLoaded = true;
      this.setData({
        conversations: normalized,
        visibleConversations: this.applyConversationFilter(normalized),
        loading: false
      });
    } catch (error) {
      if (request !== this._listRequest || account !== wx.getStorageSync('token')) return;
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '会话加载失败，请重试'
      });
    }
  },

  retryLoad() {
    this.loadData();
  },

  openChat(event) {
    if (this._openingChat) return;
    if (this._rowMoved || this._rowLongPressed) {
      this._rowMoved = false;
      this._rowLongPressed = false;
      return;
    }
    const index = Number(event.currentTarget.dataset.index);
    const item = this.data.conversations[index];
    if (!item) return;
    if ((item.offsetX || 0) < 0) {
      this.resetSwipe(index);
      return;
    }
    this._openingChat = true;
    wx.navigateTo({
      url: `/pages/profile/chat/index?id=${item.id}&name=${encodeURIComponent(item.name || '私信')}&peerUserId=${encodeURIComponent(item.peerUserId || '')}&peerAvatar=${encodeURIComponent(item.avatarUrl || '')}&blockedByMe=${item.blockedByMe ? '1' : '0'}`,
      fail: () => { this._openingChat = false; }
    });
  },

  openProfile(event) {
    const id = event.currentTarget.dataset.id || '';
    if (!id) return;
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
  },

  removeConversation(event) {
    const index = Number(event.currentTarget.dataset.index);
    const item = this.data.conversations[index];
    if (!item) return;
    wx.showModal({
      title: '删除会话',
      content: '确认删除这条会话记录？',
      confirmText: '删除',
      confirmColor: '#cb0305',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          await deleteConversation(item.id);
          const conversations = this.data.conversations.filter(entry => entry.id !== item.id);
          this.setData({
            conversations,
            visibleConversations: this.applyConversationFilter(conversations)
          });
        } catch (error) { wx.showToast({ title: '删除失败，请重试', icon: 'none' }); }
      }
    });
  },

  onConversationLongPress(event) {
    this._rowLongPressed = true;
    wx.showActionSheet({
      itemList: ['删除会话'],
      success: (result) => { if (result.tapIndex === 0) this.removeConversation(event); }
    });
  },

  onRowTouchStart(event) {
    this._rowMoved = false;
    this._rowLongPressed = false;
    const index = Number(event.currentTarget.dataset.index);
    const item = this.data.conversations[index];
    if (!item) return;
    const touch = event.touches && event.touches[0];
    if (!touch) return;
    this._touchIndex = index;
    this._touchStartX = touch.clientX;
    this._touchStartY = touch.clientY;
    this._touchStartOffset = item.offsetX || 0;
  },

  onRowTouchMove(event) {
    if (this._touchIndex === undefined || this._touchIndex === null) return;
    const touch = event.touches && event.touches[0];
    if (!touch) return;
    const dx = touch.clientX - this._touchStartX;
    const dy = touch.clientY - this._touchStartY;
    if (Math.abs(dy) > Math.abs(dx)) return;
    const rpxPerPx = this.getRpxPerPx();
    const dxRpx = dx * rpxPerPx;
    const nextOffset = Math.min(0, Math.max(this._touchStartOffset + dxRpx, -REVEAL_WIDTH_RPX));
    this.setConversationOffset(this._touchIndex, nextOffset);
    if (Math.abs(dx) > 6) {
      this._rowMoved = true;
    }
  },

  onRowTouchEnd() {
    if (this._touchIndex === undefined || this._touchIndex === null) return;
    const index = this._touchIndex;
    const item = this.data.conversations[index];
    const offsetX = item ? (item.offsetX || 0) : 0;
    const nextOffset = offsetX < -REVEAL_WIDTH_RPX / 2 ? -REVEAL_WIDTH_RPX : 0;
    this.setConversationOffset(index, nextOffset);
    this._touchIndex = null;
    this._touchStartX = 0;
    this._touchStartY = 0;
    this._touchStartOffset = 0;
  },

  resetSwipe(index) {
    this.setConversationOffset(index, 0);
  },

  setConversationOffset(index, offsetX) {
    const conversations = this.data.conversations.slice();
    const item = conversations[index];
    if (!item) return;
    item.offsetX = offsetX;
    conversations[index] = item;
    this.setData({
      conversations,
      visibleConversations: this.applyConversationFilter(conversations)
    });
  },

  getRpxPerPx() {
    if (this._rpxPerPx) return this._rpxPerPx;
    const info = wx.getWindowInfo();
    this._rpxPerPx = 750 / info.windowWidth;
    return this._rpxPerPx;
  }
});
