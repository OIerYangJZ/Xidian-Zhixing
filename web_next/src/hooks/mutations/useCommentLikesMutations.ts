import { useMutation, useQueryClient } from '@tanstack/react-query';
import { GetComment } from '@/types/definitions';
import { setCommentLiked } from '@/lib/backend/endpoints';

export function useCommentLikesMutations({ postId }: { postId: string }) {
  const qc = useQueryClient();
  const queryKey = ['posts', postId, 'comments'];

  const setLiked = (commentId: string, isLiked: boolean) =>
    qc.setQueriesData<GetComment[]>(
      { queryKey },
      (oldComments) =>
        oldComments?.map((comment) =>
          comment.id === commentId && comment.isLiked !== isLiked
            ? {
                ...comment,
                isLiked,
                _count: { ...comment._count, commentLikes: comment._count.commentLikes + (isLiked ? 1 : -1) },
              }
            : comment,
        ),
    );

  const mutationFor = (isLiked: boolean) => ({
    mutationFn: ({ commentId }: { commentId: string }) => setCommentLiked(commentId, isLiked),
    onMutate: async ({ commentId }: { commentId: string }) => {
      await qc.cancelQueries({ queryKey });
      setLiked(commentId, isLiked);
    },
    // The like response carries no count, so a failure just undoes the toggle.
    onError: (_error: unknown, { commentId }: { commentId: string }) => setLiked(commentId, !isLiked),
  });

  const likeCommentMutation = useMutation(mutationFor(true));
  const unLikeCommentMutation = useMutation(mutationFor(false));

  return { likeCommentMutation, unLikeCommentMutation };
}
