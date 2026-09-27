'use client';

import { InfiniteData, Query, useMutation, useQueryClient } from '@tanstack/react-query';
import { deletePost } from '@/lib/backend/endpoints';
import { PostIds } from '@/types/definitions';
import { useErrorNotifier } from '../useErrorNotifier';

/** Every <Posts> timeline: the feed, hashtag pages, profiles and bookmarks. */
function isPostTimeline(query: Query): boolean {
  const [head, second, third] = query.queryKey;
  return (head === 'posts' && typeof second !== 'string') || (head === 'posts' && second === 'feed') || third === 'posts';
}

export function useDeletePostMutation() {
  const qc = useQueryClient();
  const { notifyError } = useErrorNotifier();

  const deleteMutation = useMutation({
    mutationFn: ({ postId }: { postId: string }) => deletePost(postId),
    onMutate: async ({ postId }) => {
      await qc.cancelQueries({ predicate: isPostTimeline });
      const previous = qc.getQueriesData<InfiniteData<PostIds>>({ predicate: isPostTimeline });

      // Drop the post from every loaded page in place.  Pages are numbered on
      // the backend, so re-chunking would desync them from their pageParams.
      qc.setQueriesData<InfiniteData<PostIds>>({ predicate: isPostTimeline }, (oldData) =>
        oldData?.pages
          ? { ...oldData, pages: oldData.pages.map((page) => page.filter((post) => post.id !== postId)) }
          : oldData,
      );
      return { previous };
    },
    onError: (error, _variables, context) => {
      context?.previous.forEach(([key, data]) => qc.setQueryData(key, data));
      notifyError(error);
    },
    onSuccess: (_data, { postId }) => qc.removeQueries({ queryKey: ['posts', postId], exact: true }),
  });

  return { deleteMutation };
}
