import {
  NOTIFICATION_CATEGORIES,
  getNotifications,
  markAllNotificationsRead,
  markNotificationRead,
  notificationCategory
} from '../../../api/notifications';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    loading: true,
    items: [],
    // items filtered to the selected category ('' is all)
    visibleItems: [],
    category: '',
    tabs: [],
    unreadCount: 0,
    errorMessage: ''
  },

  // Rebuilds the tab counts and the filtered list from items.
  applyFilter(items = this.data.items, category = this.data.category) {
    const unread = (key) => items.filter((item) => !item.isRead
      && (!key || notificationCategory(item.type) === key)).length;
    const tabs = [{ key: '', label: '全部' }, ...NOTIFICATION_CATEGORIES]
      .map((tab) => ({ ...tab, unread: unread(tab.key) }));
    this.setData({
      items,
      category,
      tabs,
      unreadCount: unread(category),
      visibleItems: items
        .map((item, index) => ({ ...item, sourceIndex: index }))
        .filter((item) => !category || notificationCategory(item.type) === category)
    });
  },

  selectCategory(event) {
    this.applyFilter(this.data.items, event.currentTarget.dataset.key || '');
  },

  // ?category=like opens on one category, e.g. from 消息 → 赞与收藏.
  onLoad(options = {}) {
    const category = String(options.category || '');
    if (NOTIFICATION_CATEGORIES.some((tab) => tab.key === category)) {
      this.setData({ category });
    }
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadData();
  },

  onPullDownRefresh() {
    this.loadData().finally(() => wx.stopPullDownRefresh());
  },

  async loadData() {
    if (!requireLoginPage()) return;
    this.setData({ loading: true, errorMessage: '' });
    try {
      const data = await getNotifications();
      this.setData({ loading: false });
      this.applyFilter(data.items);
    } catch (error) {
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

  // Scoped to the selected category, like the list.
  async markAllRead() {
    const { category } = this.data;
    try {
      await markAllNotificationsRead(category || undefined);
      const items = this.data.items.map((item) => (
        !category || notificationCategory(item.type) === category
          ? { ...item, isRead: true }
          : item
      ));
      this.applyFilter(items);
    } catch (error) {}
  },

  async openItem(event) {
    // data-index is the position in items, not in the filtered list.
    const index = Number(event.currentTarget.dataset.index);
    const item = this.data.items[index];
    if (!item) return;
    if (!item.isRead) {
      try {
        await markNotificationRead(item.id);
      } catch (error) {
        return;
      }
      const items = this.data.items.slice();
      items[index] = { ...item, isRead: true };
      this.applyFilter(items);
    }
    const postId = item.postId || (item.relatedType === 'post' ? item.relatedId : '');
    const commentId = item.commentId || (item.relatedType === 'comment' ? item.relatedId : '');
    if (postId) {
      wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${postId}${commentId ? `&commentId=${commentId}` : ''}` });
      return;
    }
    if (item.relatedType === 'conversation' || item.type === 'message') {
      wx.navigateTo({ url: '/pages/profile/conversations/index' });
      return;
    }
    if (item.relatedType === 'user') {
      wx.navigateTo({ url: `/pages/profile/public-user/index?id=${item.relatedId}` });
    }
  }
});
