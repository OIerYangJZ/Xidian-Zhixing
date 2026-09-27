'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { setPostReposted } from '@/lib/backend/endpoints';
import { useErrorNotifier } from '@/hooks/useErrorNotifier';
import { useToast } from '@/hooks/useToast';
import { GetPost } from '@/types/definitions';

export function usePostRepostMutation({ postId }: { postId: string }) {
  const qc = useQueryClient();
  const queryKey = ['posts', postId];
  const { showToast } = useToast();
  const { notifyError } = useErrorNotifier();

  const setReposted = (isReposted: boolean) =>
    qc.setQueryData<GetPost>(queryKey, (post) =>
      post && post.isReposted !== isReposted
        ? {
            ...post,
            isReposted,
            _count: { ...post._count, reposts: Math.max(0, post._count.reposts + (isReposted ? 1 : -1)) },
          }
        : post,
    );

  return useMutation({
    mutationFn: (next: boolean) => setPostReposted(postId, next),
    onMutate: async (next) => {
      await qc.cancelQueries({ queryKey });
      setReposted(next);
    },
    onSuccess: ({ reposted, repostCount }) => {
      qc.setQueryData<GetPost>(queryKey, (post) =>
        post ? { ...post, isReposted: reposted, _count: { ...post._count, reposts: repostCount } } : post,
      );
      // The reposter's profile timeline gains or loses the entry.
      qc.invalidateQueries({ predicate: ({ queryKey: key }) => key[0] === 'users' && key[2] === 'posts' });
      showToast({ title: reposted ? '已转发' : '已取消转发', type: 'success' });
    },
    onError: (error, next) => {
      setReposted(!next);
      notifyError(error, next ? '转发失败' : '取消转发失败');
    },
  });
}
