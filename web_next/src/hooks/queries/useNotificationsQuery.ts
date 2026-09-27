import { useQuery } from '@tanstack/react-query';
import { useSession } from '@/lib/backend/session';
import { listNotifications } from '@/lib/backend/endpoints';
import { toGetActivity } from '@/lib/backend/adapters';
import type { ApiNotificationType } from '@/lib/backend/types';
import type { GetActivity } from '@/types/definitions';

export const NOTIFICATIONS_QUERY_KEY = ['notifications'];

export interface NotificationsData {
  items: (GetActivity & { category: ApiNotificationType })[];
  unreadCount: number;
  unreadByType: Record<ApiNotificationType, number>;
}

const CATEGORIES: ApiNotificationType[] = ['comment', 'reply', 'like', 'favorite', 'report_result', 'system'];

/**
 * One request serves both the list and the unread badge: the backend returns
 * every notification (at most 500) together with the unread counts.
 */
export function useNotificationsQuery<T = NotificationsData>(select?: (data: NotificationsData) => T) {
  const { data: session, status } = useSession();
  return useQuery({
    queryKey: NOTIFICATIONS_QUERY_KEY,
    enabled: status === 'authenticated',
    refetchInterval: 30000,
    queryFn: async (): Promise<NotificationsData> => {
      const data = await listNotifications();
      const me = {
        id: session?.user.id || '',
        username: session?.user.id || '',
        name: session?.user.name || '',
        profilePhoto: null,
      };
      return {
        items: data.items.map((item) => ({
          ...toGetActivity(item, me),
          // Unknown types count as system, as the backend's own counters do.
          category: (CATEGORIES as string[]).includes(item.type) ? (item.type as ApiNotificationType) : 'system',
        })),
        unreadCount: data.unreadCount,
        unreadByType: data.unreadByType,
      };
    },
    select,
  });
}
