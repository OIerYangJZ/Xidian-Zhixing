import request from '../utils/request';
import {
  getData,
  normalizeNotification,
  responseContractError
} from '../utils/format';
import { getCurrentUserId } from './session';

export const getNotifications = async () => {
  const userId = await getCurrentUserId();
  const [listResponse, countResponse] = await Promise.all([
    request.get(`/api/users/${encodeURIComponent(userId)}/notifications`, { limit: 50 }),
    request.get(`/api/users/${encodeURIComponent(userId)}/notifications/count`)
  ]);
  const rows = getData(listResponse, []);
  const unreadCount = getData(countResponse, 0);
  if (!Array.isArray(rows)) throw responseContractError('通知列表响应不是数组');
  return {
    items: rows.map((item) => {
      const type = String(item.type || '');
      const isFollow = type === 'CREATE_FOLLOW';
      const isPost = type === 'POST_LIKE' || type === 'POST_MENTION';
      const isComment = type === 'COMMENT_LIKE' || type === 'REPLY_LIKE' || type === 'COMMENT_MENTION' || type === 'CREATE_COMMENT' || type === 'CREATE_REPLY';
      const relatedId = isFollow
        ? item.sourceUser && item.sourceUser.id
        : isPost
          ? (type === 'POST_LIKE' ? item.targetId : item.sourceId)
          : (type.endsWith('_LIKE') ? item.targetId : item.sourceId);
      return normalizeNotification({
        ...item,
        title: item.sourceUser && item.sourceUser.name ? item.sourceUser.name : '知行动态',
        actorAlias: item.sourceUser && (item.sourceUser.name || item.sourceUser.username),
        content: item.content || '',
        actorAvatarUrl: item.sourceUser && item.sourceUser.profilePhoto,
        isRead: item.isNotificationRead,
        type: isFollow ? 'follow' : isPost ? 'like' : isComment ? 'reply' : 'system',
        relatedType: isFollow ? 'user' : isComment ? 'comment' : isPost ? 'post' : '',
        relatedId,
        postId: isPost ? relatedId : (type === 'CREATE_COMMENT' ? item.targetId : ''),
        commentId: isComment ? relatedId : ''
      });
    }),
    unreadCount: Number(unreadCount) || 0
  };
};

export const markAllNotificationsRead = async () => {
  const userId = await getCurrentUserId();
  const response = await request.patch(`/api/users/${encodeURIComponent(userId)}/notifications`, {});
  const data = getData(response, {});
  return data;
};

export const markNotificationRead = async (notificationId) => {
  const userId = await getCurrentUserId();
  const response = await request.patch(`/api/users/${encodeURIComponent(userId)}/notifications/${encodeURIComponent(notificationId)}`, {});
  return getData(response, {});
};
