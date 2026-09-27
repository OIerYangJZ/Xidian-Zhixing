import { useMutation, useQueryClient } from '@tanstack/react-query';
import { GetUser } from '@/types/definitions';
import { followUser, unfollowUser } from '@/lib/backend/endpoints';
import { useToast } from '../useToast';

export function useFollowsMutations({ targetUserId }: { targetUserId: string }) {
  const qc = useQueryClient();
  const queryKey = ['users', targetUserId];
  const { showToast } = useToast();

  const followMutation = useMutation({
    mutationFn: () => followUser(targetUserId),
    onMutate: async () => {
      // Cancel outgoing queries and snapshot the prev value
      await qc.cancelQueries({ queryKey });
      const previousTargetUser = qc.getQueryData(queryKey);

      // Optimistically update the UI
      qc.setQueryData<GetUser>(queryKey, (oldTargetUser) => {
        if (!oldTargetUser) return oldTargetUser;
        return {
          ...oldTargetUser,
          isFollowing: true,
          followerCount: (oldTargetUser.followerCount || 0) + 1,
        };
      });

      // Return a context object with the snapshotted value
      return { previousTargetUser };
    },
    onError: (err: Error, variables, context) => {
      qc.setQueryData(queryKey, context?.previousTargetUser);
      showToast({
        title: 'Something Went Wrong',
        message: err.message,
        type: 'error',
      });
    },
  });

  const unFollowMutation = useMutation({
    mutationFn: () => unfollowUser(targetUserId),
    onMutate: async () => {
      // Cancel outgoing queries and snapshot the prev value
      await qc.cancelQueries({ queryKey });
      const previousTargetUser = qc.getQueryData(queryKey);

      // Optimistically update the UI
      qc.setQueryData<GetUser>(queryKey, (oldTargetUser) => {
        if (!oldTargetUser) return oldTargetUser;
        return {
          ...oldTargetUser,
          isFollowing: false,
          followerCount: (oldTargetUser.followerCount || 0) - 1,
        };
      });

      // Return a context object with the snapshotted value
      return { previousTargetUser };
    },
    onError: (err: Error, variables, context) => {
      qc.setQueryData(queryKey, context?.previousTargetUser);
      showToast({
        title: 'Something Went Wrong',
        message: err.message,
        type: 'error',
      });
    },
  });

  return { followMutation, unFollowMutation };
}
