import {
  NOTIFICATION_CATEGORIES,
  getNotifications,
  markAllNotificationsRead,
  markNotificationRead,
  notificationCategory
} from '../../../api/notifications';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

// Handoff N1: each category's icon and tile tone.
const CATEGORY_LOOK = {
  comment: { icon: 'comment', tone: 'info' },
  reply: { icon: 'reply', tone: 'success' },
  like: { icon: 'heart', tone: 'danger' },
  favorite: { icon: 'star', tone: 'accent' },
  report_result: { icon: 'shield', tone: 'success' },
  system: { icon: 'bell', tone: 'neutral' }
};

// category is '' (all), one key, or keys joined by commas: 消息's
// 评论回复 and 赞与收藏 entries each open two categories.
const inCategory = (item, category) => !category
  || category.split(',').includes(notificationCategory(item.type));

Page({
  data: {
    loading: true,
    items: [],
    // the selected category ('' is all), grouped 今天 / 更早
    groups: [],
    visibleCount: 0,
    category: '',
    tabs: [],
    unreadCount: 0,
    errorMessage: ''
  },

  // Rebuilds the tab counts and the list, grouped 今天 / 更早, from items.
  applyFilter(items = this.data.items, category = this.data.category) {
    const unread = (key) => items.filter((item) => !item.isRead && inCategory(item, key)).length;
    const tabs = [{ key: '', label: '全部' }, ...NOTIFICATION_CATEGORIES]
      .map((tab) => ({
        ...tab,
        unread: unread(tab.key),
        // A grouped category lights each of its chips.
        on: tab.key ? category.split(',').includes(tab.key) : !category
      }));
    const now = new Date();
    const isToday = (value) => {
      const d = new Date(String(value || ''));
      return !Number.isNaN(d.getTime()) && d.getFullYear() === now.getFullYear()
        && d.getMonth() === now.getMonth() && d.getDate() === now.getDate();
    };
    const rows = items
      .map((item, index) => ({ ...item, sourceIndex: index, ...CATEGORY_LOOK[notificationCategory(item.type)] }))
      .filter((item) => inCategory(item, category));
    const groups = [
      { key: 'today', label: '今天', rows: rows.filter((item) => isToday(item.createdAt)) },
      { key: 'earlier', label: '更早', rows: rows.filter((item) => !isToday(item.createdAt)) }
    ].filter((group) => group.rows.length);
    this.setData({
      items,
      category,
      tabs,
      unreadCount: unread(category),
      visibleCount: rows.length,
      groups
    });
  },

  selectCategory(event) {
    this.applyFilter(this.data.items, event.currentTarget.dataset.key || '');
  },

  // ?category=like,favorite opens on those categories, e.g. from 消息 → 赞与收藏.
  onLoad(options = {}) {
    const category = String(options.category || '');
    if (category && category.split(',').every((key) => NOTIFICATION_CATEGORIES.some((tab) => tab.key === key))) {
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
      if (category) {
        await Promise.all(category.split(',').map((key) => markAllNotificationsRead(key)));
      } else {
        await markAllNotificationsRead();
      }
      const items = this.data.items.map((item) => (
        inCategory(item, category)
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
      wx.switchTab({ url: '/pages/messages/index' });
      return;
    }
    if (item.relatedType === 'user') {
      wx.navigateTo({ url: `/pages/profile/public-user/index?id=${item.relatedId}` });
    }
    // A reply to 信箱 feedback: the records list shows it.
    if (item.relatedType === 'feedback') {
      wx.navigateTo({ url: '/pages/profile/feedback/index' });
    }
  }
});
