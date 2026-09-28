import request from '../utils/request';
import {
  getData,
  normalizeNotification,
  responseContractError
} from '../utils/format';

export const getNotifications = async () => {
  const response = await request.get('/api/notifications');
  const data = getData(response, {});
  if (!Array.isArray(data.items)) {
    throw responseContractError('通知列表响应 items 不是数组');
  }
  if (typeof data.unreadCount !== 'number' || !Number.isInteger(data.unreadCount) || data.unreadCount < 0) {
    throw responseContractError('通知列表响应 unreadCount 无效');
  }
  return {
    items: data.items.map(normalizeNotification),
    unreadCount: data.unreadCount
  };
};

// Marks everything read, or only one category (see NOTIFICATION_CATEGORIES).
export const markAllNotificationsRead = async (category) => {
  const response = await request.post('/api/notifications/read-all', category ? { type: category } : {});
  const data = getData(response, {});
  if (data.ok !== true) {
    throw responseContractError('全部已读响应未确认成功');
  }
  return data;
};

export const markNotificationRead = async (notificationId) => {
  const response = await request.get(`/api/notifications/${notificationId}/read`);
  return normalizeNotification(getData(response, {}));
};

// Filter categories, the same mapping as the server's notification_category:
// unknown types and announcements count as system.
export const NOTIFICATION_CATEGORIES = [
  { key: 'comment', label: '评论' },
  { key: 'reply', label: '回复' },
  { key: 'like', label: '点赞' },
  { key: 'favorite', label: '收藏' },
  { key: 'repost', label: '转发' },
  { key: 'mention', label: '@我' },
  { key: 'report_result', label: '举报结果' },
  { key: 'system', label: '系统' }
];

export const notificationCategory = (type) => {
  const normalized = String(type || '').trim().toLowerCase();
  return NOTIFICATION_CATEGORIES.some((c) => c.key === normalized) ? normalized : 'system';
};
