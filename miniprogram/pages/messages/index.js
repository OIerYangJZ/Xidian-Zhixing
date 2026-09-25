import { getConversations } from '../../api/messages';
import { getNotifications, notificationCategory } from '../../api/notifications';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage, setMessagesTabBadge } from '../../utils/theme_i18n';

// 消息 tab (handoff A3): 通知 / 评论回复 / 赞与收藏, then the conversations.
// There are no message requests: a first message goes straight into a chat.
Page({
  data: {
    loading: true,
    errorMessage: '',
    conversations: [],
    notificationUnread: 0,
    commentUnread: 0,
    likeUnread: 0,
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
      const [conversations, notifications] = await Promise.all([
        getConversations(),
        getNotifications().catch(() => ({ items: [], unreadCount: 0 }))
      ]);
      const commentUnread = notifications.items.filter((item) => !item.isRead
        && ['comment', 'reply'].includes(notificationCategory(item.type))).length;
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
        commentUnread,
        notificationUnread: notifications.unreadCount,
        likeUnread
      });
      setMessagesTabBadge(conversationUnread + notifications.unreadCount);
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

  openComments() {
    wx.navigateTo({ url: '/pages/profile/notifications/index?category=comment' });
  },

  openChat(event) {
    const item = this.data.conversations[Number(event.currentTarget.dataset.index)];
    if (!item) return;
    wx.navigateTo({
      url: `/pages/profile/chat/index?id=${item.id}&name=${encodeURIComponent(item.name || '私信')}&peerUserId=${encodeURIComponent(item.peerUserId || '')}&peerAvatar=${encodeURIComponent(item.avatarUrl || '')}&blockedByMe=${item.blockedByMe ? '1' : '0'}&blockedByPeer=${item.blockedByPeer ? '1' : '0'}&awaitingReply=${item.awaitingReply ? '1' : '0'}`
    });
  },

  retryLoad() {
    this.loadData();
  }
});
