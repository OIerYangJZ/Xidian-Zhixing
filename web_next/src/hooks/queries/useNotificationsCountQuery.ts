import { useNotificationsQuery } from './useNotificationsQuery';

/** Unread badge; shares the notifications query, so it costs no request of its own. */
export function useNotificationsCountQuery() {
  return useNotificationsQuery((data) => data.unreadCount);
}
