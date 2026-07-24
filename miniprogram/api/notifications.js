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

export const markAllNotificationsRead = async () => {
  const response = await request.post('/api/notifications/read-all', {});
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
