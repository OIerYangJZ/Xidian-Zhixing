import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useDialogs } from '@/hooks/useDialogs';
import { useErrorNotifier } from '@/hooks/useErrorNotifier';
import { useLanguage } from '@/hooks/useLanguage';
import { deleteComment } from '@/lib/backend/endpoints';
import { GetComment, GetPost } from '@/types/definitions';

/** Deleting only: the backend has no comment edit. */
export function useUpdateDeleteComments({ postId }: { postId: string }) {
  const qc = useQueryClient();
  const { confirm } = useDialogs();
  const { notifyError } = useErrorNotifier();
  const { t } = useLanguage();
  const queryKey = ['posts', postId, 'comments'];

  const deleteCommentMutation = useMutation({
    mutationFn: ({ commentId }: { commentId: string }) => deleteComment(commentId),
    onMutate: async ({ commentId }) => {
      await qc.cancelQueries({ queryKey });
      const previous = qc.getQueriesData<GetComment[]>({ queryKey });
      qc.setQueriesData<GetComment[]>({ queryKey }, (oldComments) =>
        oldComments?.filter((comment) => comment.id !== commentId),
      );
      return { previous };
    },
    onSuccess: () =>
      qc.setQueryData<GetPost>(['posts', postId], (post) =>
        post ? { ...post, _count: { ...post._count, comments: Math.max(0, post._count.comments - 1) } } : post,
      ),
    onError: (error, _variables, context) => {
      context?.previous.forEach(([key, data]) => qc.setQueryData(key, data));
      notifyError(error, t('删除失败', 'Could not delete'));
    },
  });

  const handleDelete = ({ commentId }: { commentId: string }) => {
    confirm({
      title: t('删除评论', 'Delete comment'),
      message: t('确定删除这条评论吗？', 'Delete this comment?'),
      onConfirm: () => {
        // Wait for the dialog to close before deleting the comment to pass the focus to
        // the next element first, preventing the focus from resetting to the top
        setTimeout(() => deleteCommentMutation.mutate({ commentId }), 300);
      },
    });
  };

  return { handleDelete };
}
