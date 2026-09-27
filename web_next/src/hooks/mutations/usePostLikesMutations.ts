'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { setPostLiked } from '@/lib/backend/endpoints';
import { GetPost } from '@/types/definitions';

export function usePostLikesMutations({ postId }: { postId: string }) {
  const qc = useQueryClient();
  const queryKey = ['posts', postId];

  const likeMutation = useMutation({
    mutationFn: () => setPostLiked(postId, true),
    onMutate: async () => {
      // Cancel any outgoing refetches
      await qc.cancelQueries({ queryKey });

      // Snapshot the previous value
      const previousPost = qc.getQueryData(queryKey);

      // Optimistically the post
      qc.setQueryData<GetPost>(queryKey, (oldPost) => {
        if (!oldPost) return oldPost;

        return {
          ...oldPost,
          _count: {
            ...oldPost._count,
            postLikes: oldPost._count.postLikes + 1,
          },
          isLiked: true,
        };
      });

      // Return a context object with the snapshotted value
      return { previousPost };
    },
    onError: (err, variables, context) => {
      qc.setQueryData(queryKey, context?.previousPost);
    },
  });

  const unLikeMutation = useMutation({
    mutationFn: () => setPostLiked(postId, false),
    onMutate: async () => {
      // Cancel any outgoing refetches
      await qc.cancelQueries({ queryKey });

      // Snapshot the previous value
      const previousPost = qc.getQueryData(queryKey);

      // Optimistically the post
      qc.setQueryData<GetPost>(queryKey, (oldPost) => {
        if (!oldPost) return oldPost;

        return {
          ...oldPost,
          _count: {
            ...oldPost._count,
            postLikes: oldPost._count.postLikes - 1,
          },
          isLiked: false,
        };
      });

      // Return a context object with the snapshotted value
      return { previousPost };
    },
    onError: (err, variables, context) => {
      qc.setQueryData(queryKey, context?.previousPost);
    },
  });

  return { likeMutation, unLikeMutation };
}
