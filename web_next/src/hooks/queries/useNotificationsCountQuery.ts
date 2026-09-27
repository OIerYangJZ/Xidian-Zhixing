import { getNotificationsCount } from '@/lib/client_data_fetching/getNotificationsCount';
import { useQuery } from '@tanstack/react-query';
import { useSession } from '@/lib/backend/session';

export function useNotificationsCountQuery() {
  const { data: session } = useSession();
  const userId = session?.user.id;

  return useQuery<number>({
    queryKey: ['users', userId, 'notifications', 'count'],
    queryFn: async () => getNotificationsCount({ userId: userId! }),
    refetchInterval: 30000,
    enabled: !!userId,
  });
}
