import { enterPage, enterContent } from '../../../utils/motion';
import { getNotifications, markAllNotificationsRead, markNotificationRead } from '../../../api/notifications';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const isReplyNotification = (item) => {
  const type = String(item.type || '').toLowerCase();
  if (['reply', 'comment', 'mention'].includes(type)) return true;
  if (['like', 'favorite', 'follow', 'system', 'system_announcement', 'report_result', 'message'].includes(type)) return false;
  const value = `${item.type || ''} ${item.relatedType || ''} ${item.title || ''}`.toLowerCase();
  return /reply|comment|mention|回复|评论|提及/.test(value);
};

const decorateNotification = (item) => {
  const type = String(item.type || '').toLowerCase();
  const noticeKind = isReplyNotification(item) ? 'reply'
    : type === 'like' ? 'like'
    : type === 'favorite' ? 'favorite'
    : type === 'follow' ? 'follow' : 'system';
  const icons = { reply: 'chat', like: 'heart', favorite: 'bookmark', follow: 'person', system: 'bell' };
  return { ...item, noticeKind, noticeIcon: icons[noticeKind], actorInitial: Array.from(item.actorAlias || '电')[0] };
};

Page({
  data: {
    navTop: 0,
    navHeight: 32,
    loading: true,
    refreshing: false,
    markingRead: false,
    items: [],
    displayedItems: [],
    activeFilter: 'all',
    unreadCount: 0,
    errorMessage: ''
  },

  onShow() {
    enterPage(this, { animate: false });
    applyThemeAndLanguage(this);
    this.initLayout();
    if (!requireLoginPage()) return;
    this.loadData();
  },

  onUnload() { this._listRequest = (this._listRequest || 0) + 1; },

  initLayout() {
    const app = getApp();
    this.setData({
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32
    });
  },

  applyFilter(items = this.data.items, activeFilter = this.data.activeFilter) {
    return activeFilter === 'replies' ? items.filter(isReplyNotification) : items;
  },

  switchFilter(event) {
    const activeFilter = event.currentTarget.dataset.filter;
    if (!['all', 'replies'].includes(activeFilter) || activeFilter === this.data.activeFilter) return;
    enterContent(this, {
      activeFilter,
      displayedItems: this.applyFilter(this.data.items, activeFilter)
    }, activeFilter === 'replies' ? 1 : -1);
  },

  openNotificationSettings() {
    wx.navigateTo({ url: '/pages/profile/privacy/index?section=notifications' });
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
    if (!requireLoginPage()) return;
    const account = wx.getStorageSync('token');
    if (account !== this._inboxAccount) {
      this._inboxAccount = account;
      this._hasLoaded = false;
      this.setData({ items: [], displayedItems: [], unreadCount: 0 });
    }
    const request = this._listRequest = (this._listRequest || 0) + 1;
    this.setData({ loading: !this._hasLoaded, errorMessage: '' });
    try {
      const data = await getNotifications();
      if (request !== this._listRequest || account !== wx.getStorageSync('token')) return;
      const items = data.items.map(decorateNotification);
      this._hasLoaded = true;
      this.setData({
        items,
        displayedItems: this.applyFilter(items),
        unreadCount: data.unreadCount,
        loading: false
      });
    } catch (error) {
      if (request !== this._listRequest || account !== wx.getStorageSync('token')) return;
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '通知加载失败，请重试'
      });
    }
  },

  retryLoad() {
    this.loadData();
  },

  async markAllRead() {
    if (this.data.markingRead || !this.data.unreadCount) return;
    this.setData({ markingRead: true });
    try {
      await markAllNotificationsRead();
      const items = this.data.items.map((item) => ({ ...item, isRead: true }));
      this.setData({ items, displayedItems: this.applyFilter(items), unreadCount: 0 });
    } catch (error) {
      wx.showToast({ title: '标记失败，请重试', icon: 'none' });
    } finally {
      this.setData({ markingRead: false });
    }
  },

  async openItem(event) {
    const index = Number(event.currentTarget.dataset.index);
    const item = this.data.displayedItems[index];
    if (!item) return;
    if (!item.isRead) {
      try {
        await markNotificationRead(item.id);
      } catch (error) {
        return;
      }
      const items = this.data.items.map((entry) => entry.id === item.id ? { ...entry, isRead: true } : entry);
      this.setData({
        items,
        displayedItems: this.applyFilter(items),
        unreadCount: Math.max(0, this.data.unreadCount - 1)
      });
    }
    const postId = item.postId || (item.relatedType === 'post' ? item.relatedId : '');
    const commentId = item.commentId || (item.relatedType === 'comment' ? item.relatedId : '');
    if (postId) {
      wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${postId}${commentId ? `&commentId=${commentId}` : ''}` });
      return;
    }
    if (item.relatedType === 'conversation' || item.type === 'message') {
      wx.switchTab({ url: '/pages/profile/conversations/index' });
      return;
    }
    if (item.relatedType === 'user') {
      wx.navigateTo({ url: `/pages/profile/public-user/index?id=${item.relatedId}` });
    }
  }
});
