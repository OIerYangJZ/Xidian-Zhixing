import { getUser } from '@/lib/backend/endpoints';
import { useSession } from '@/lib/backend/session';
import { useQuery } from '@tanstack/react-query';

/**
 * Always use this query hook when querying user data/subscribing to a user data query.
 * The signed-in user's own profile comes from /api/users/me, everyone else's from /api/users/<id>.
 */
export function useUserQuery(userId?: string) {
  const { data: session } = useSession();
  return useQuery({
    queryKey: ['users', userId],
    queryFn: () => getUser(userId!, session?.user.id),
    enabled: !!userId,
    staleTime: 60000 * 10,
  });
}
