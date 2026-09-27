import { useMutation, useQueryClient } from '@tanstack/react-query';
import { GetComment, GetPost } from '@/types/definitions';
import { createComment } from '@/lib/backend/endpoints';
import { useErrorNotifier } from '../useErrorNotifier';
import { useToast } from '../useToast';

/** A comment or, with `parentId`, a reply at any depth. */
export function useCreateCommentMutations() {
  const qc = useQueryClient();
  const { showToast } = useToast();
  const { notifyError } = useErrorNotifier();

  const createCommentMutation = useMutation({
    mutationFn: ({ postId, content, parentId }: { postId: string; content: string; parentId?: string }) =>
      createComment(postId, content, parentId),
    onSuccess: (created) => {
      // Both sort orders of this post's comments hold the same flat list.
      qc.setQueriesData<GetComment[]>({ queryKey: ['posts', created.postId, 'comments'] }, (oldComments) =>
        oldComments ? [created, ...oldComments] : oldComments,
      );
      qc.setQueryData<GetPost>(['posts', created.postId], (post) =>
        post ? { ...post, _count: { ...post._count, comments: post._count.comments + 1 } } : post,
      );
      showToast({
        title: created.isPending ? '评论已提交审核' : created.parentId ? '回复成功' : '评论成功',
        type: 'success',
      });
    },
    onError: (err) => {
      notifyError(err, '评论失败');
    },
  });

  return { createCommentMutation };
}
