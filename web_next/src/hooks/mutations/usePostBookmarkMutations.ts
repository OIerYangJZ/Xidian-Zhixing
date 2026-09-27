'use client';

import { GetPost } from '@/types/definitions';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useSession } from '@/lib/backend/session';
import { setPostFavorited } from '@/lib/backend/endpoints';

export function usePostBookmarkMutations({ postId }: { postId: string }) {
  const queryClient = useQueryClient();
  const queryKey = ['posts', postId];
  const { data: session } = useSession();

  const setBookmarked = (isBookmarked: boolean) =>
    queryClient.setQueryData<GetPost>(queryKey, (oldPost) =>
      oldPost
        ? {
            ...oldPost,
            isBookmarked,
            _count: { ...oldPost._count, bookmarks: oldPost._count.bookmarks + (isBookmarked ? 1 : -1) },
          }
        : oldPost,
    );
  const invalidateBookmarkData = async () => {
    await queryClient.invalidateQueries({ queryKey });
    if (session?.user?.id) {
      await queryClient.invalidateQueries({
        queryKey: ['users', session.user.id, 'posts', { type: 'bookmarks' }],
      });
    }
  };

  const bookmarkMutation = useMutation({
    mutationFn: () => setPostFavorited(postId, true),
    onMutate: async () => {
      await queryClient.cancelQueries({ queryKey });
      const previousPost = queryClient.getQueryData<GetPost>(queryKey);
      setBookmarked(true);
      return { previousPost };
    },
    onError: (_error, _variables, context) => queryClient.setQueryData(queryKey, context?.previousPost),
    onSettled: invalidateBookmarkData,
  });

  const removeBookmarkMutation = useMutation({
    mutationFn: () => setPostFavorited(postId, false),
    onMutate: async () => {
      await queryClient.cancelQueries({ queryKey });
      const previousPost = queryClient.getQueryData<GetPost>(queryKey);
      setBookmarked(false);
      return { previousPost };
    },
    onError: (_error, _variables, context) => queryClient.setQueryData(queryKey, context?.previousPost),
    onSettled: invalidateBookmarkData,
  });

  return { bookmarkMutation, removeBookmarkMutation };
}
