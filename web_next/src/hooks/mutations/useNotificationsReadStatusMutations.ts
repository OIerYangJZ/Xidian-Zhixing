import { useMutation, useQueryClient } from '@tanstack/react-query';
import { markAllNotificationsRead, markNotificationRead } from '@/lib/backend/endpoints';
import type { ApiNotificationType } from '@/lib/backend/types';
import { NOTIFICATIONS_QUERY_KEY, type NotificationsData } from '../queries/useNotificationsQuery';

export function useNotificationsReadStatusMutations() {
  const qc = useQueryClient();

  const setRead = (predicate: (item: NotificationsData['items'][number]) => boolean) =>
    qc.setQueryData<NotificationsData>(NOTIFICATIONS_QUERY_KEY, (data) => {
      if (!data) return data;
      const unreadByType = { ...data.unreadByType };
      let unreadCount = data.unreadCount;
      const items = data.items.map((item) => {
        if (item.isNotificationRead || !predicate(item)) return item;
        unreadByType[item.category] = Math.max(0, (unreadByType[item.category] || 0) - 1);
        unreadCount = Math.max(0, unreadCount - 1);
        return { ...item, isNotificationRead: true };
      });
      return { items, unreadCount, unreadByType };
    });

  const markAsReadMutation = useMutation({
    mutationFn: ({ notificationId }: { notificationId: string }) => markNotificationRead(notificationId),
    onMutate: ({ notificationId }) => setRead((item) => item.id === notificationId),
  });

  const markAllAsReadMutation = useMutation({
    mutationFn: (type?: ApiNotificationType) => markAllNotificationsRead(type),
    onMutate: (type) => setRead((item) => !type || item.category === type),
    // Coalesced like/favorite notifications can come back unread (see the
    // contract notes), so take the server's view once it has answered.
    onSettled: () => qc.invalidateQueries({ queryKey: NOTIFICATIONS_QUERY_KEY }),
  });

  return { markAsReadMutation, markAllAsReadMutation };
}
