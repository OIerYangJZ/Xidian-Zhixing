import { getDmRequests, getConversations, handleDmRequest } from '../../api/messages';
import { getNotifications, notificationCategory } from '../../api/notifications';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage, setMessagesTabBadge } from '../../utils/theme_i18n';

// 消息 tab (handoff A3): 通知 / 私信请求 / 赞与收藏, the first pending
// request with 同意 / 拒绝, then the conversations.
Page({
  data: {
    loading: true,
    errorMessage: '',
    conversations: [],
    pendingRequests: [],
    notificationUnread: 0,
    likeUnread: 0,
    busy: false,
    navTop: 44,
    navHeight: 32
  },

  onShow() {
    const app = getApp();
    this.setData({ navTop: app.globalData.navTop || 44, navHeight: app.globalData.navHeight || 32 });
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadData();
  },

  onPullDownRefresh() {
    this.loadData().finally(() => wx.stopPullDownRefresh());
  },

  async loadData() {
    this.setData({ loading: this.data.conversations.length === 0, errorMessage: '' });
    try {
      const [conversations, requests, notifications] = await Promise.all([
        getConversations(),
        getDmRequests().catch(() => []),
        getNotifications().catch(() => ({ items: [], unreadCount: 0 }))
      ]);
      const pendingRequests = requests.filter((item) => item.status === 'pending');
      const likeUnread = notifications.items.filter((item) => !item.isRead
        && ['like', 'favorite'].includes(notificationCategory(item.type))).length;
      const conversationUnread = conversations
        .reduce((sum, item) => sum + (Number(item.unreadCount) || 0), 0);
      this.setData({
        loading: false,
        conversations: conversations.map((item) => ({
          ...item,
          unread: Number(item.unreadCount) || 0,
          unreadText: (Number(item.unreadCount) || 0) > 99 ? '99+' : String(item.unreadCount || '')
        })),
        pendingRequests,
        notificationUnread: notifications.unreadCount,
        likeUnread
      });
      setMessagesTabBadge(conversationUnread + notifications.unreadCount + pendingRequests.length);
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '消息加载失败，请重试'
      });
    }
  },

  openNotifications() {
    wx.navigateTo({ url: '/pages/profile/notifications/index' });
  },

  openLikes() {
    wx.navigateTo({ url: '/pages/profile/notifications/index?category=like' });
  },

  scrollToRequests() {
    if (!this.data.pendingRequests.length) {
      wx.showToast({ title: '暂无私信请求', icon: 'none' });
    }
  },

  async answerRequest(event) {
    const { id, accept } = event.currentTarget.dataset;
    if (!id || this.data.busy) return;
    this.setData({ busy: true });
    try {
      await handleDmRequest(id, accept === '1');
      wx.showToast({ title: accept === '1' ? '已同意' : '已拒绝', icon: 'none' });
      await this.loadData();
    } catch (error) {
      wx.showToast({ title: '操作失败，请重试', icon: 'none' });
    } finally {
      this.setData({ busy: false });
    }
  },

  openChat(event) {
    const item = this.data.conversations[Number(event.currentTarget.dataset.index)];
    if (!item) return;
    wx.navigateTo({
      url: `/pages/profile/chat/index?id=${item.id}&name=${encodeURIComponent(item.name || '私信')}&peerUserId=${encodeURIComponent(item.peerUserId || '')}&peerAvatar=${encodeURIComponent(item.avatarUrl || '')}&blockedByMe=${item.blockedByMe ? '1' : '0'}`
    });
  },

  retryLoad() {
    this.loadData();
  }
});
