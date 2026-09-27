import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useDialogs } from '@/hooks/useDialogs';
import { useErrorNotifier } from '@/hooks/useErrorNotifier';
import { useLanguage } from '@/hooks/useLanguage';
import { deleteComment, editComment } from '@/lib/backend/endpoints';
import { mentionIdsIn } from '@/lib/mentions';
import { GetComment, GetPost, Mention } from '@/types/definitions';

/** Editing and deleting one's own comments and replies. */
export function useUpdateDeleteComments({ postId }: { postId: string }) {
  const qc = useQueryClient();
  const { confirm, prompt } = useDialogs();
  const { notifyError } = useErrorNotifier();
  const { t } = useLanguage();
  const queryKey = ['posts', postId, 'comments'];

  const deleteCommentMutation = useMutation({
    mutationFn: ({ commentId }: { commentId: string }) => deleteComment(commentId),
    onMutate: async ({ commentId }) => {
      await qc.cancelQueries({ queryKey });
      const previous = qc.getQueriesData<GetComment[]>({ queryKey });
      qc.setQueriesData<GetComment[]>(
        { queryKey },
        (oldComments) => oldComments?.filter((comment) => comment.id !== commentId),
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

  const editCommentMutation = useMutation({
    mutationFn: ({ commentId, content, mentions }: { commentId: string; content: string; mentions: Mention[] }) =>
      editComment(commentId, content, mentionIdsIn(content, mentions)),
    onMutate: async ({ commentId, content }) => {
      await qc.cancelQueries({ queryKey });
      const previous = qc.getQueriesData<GetComment[]>({ queryKey });
      qc.setQueriesData<GetComment[]>(
        { queryKey },
        (oldComments) => oldComments?.map((comment) => (comment.id === commentId ? { ...comment, content } : comment)),
      );
      return { previous };
    },
    // Keep threading data from the list; take the text, mentions and review
    // state the server settled on.
    onSuccess: (edited) =>
      qc.setQueriesData<GetComment[]>(
        { queryKey },
        (oldComments) =>
          oldComments?.map((comment) =>
            comment.id === edited.id
              ? {
                  ...comment,
                  content: edited.content,
                  mentions: edited.mentions,
                  editedAt: edited.editedAt,
                  isPending: edited.isPending,
                }
              : comment,
          ),
      ),
    onError: (error, _variables, context) => {
      context?.previous.forEach(([key, data]) => qc.setQueryData(key, data));
      notifyError(error, t('编辑失败', 'Could not edit'));
    },
  });

  const handleEdit = ({
    commentId,
    content,
    mentions,
  }: {
    commentId: string;
    content: string;
    mentions: Mention[];
  }) => {
    prompt({
      title: t('编辑评论', 'Edit comment'),
      message: '',
      initialPromptValue: content,
      promptType: 'textarea',
      onSubmit: (value) => {
        if (value.trim() && value !== content) editCommentMutation.mutate({ commentId, content: value, mentions });
      },
    });
  };

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

  return { handleEdit, handleDelete };
}
