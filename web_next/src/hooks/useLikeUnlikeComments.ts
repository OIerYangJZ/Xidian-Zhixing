import { useCommentLikesMutations } from './mutations/useCommentLikesMutations';

export function useLikeUnlikeComments({ postId }: { postId: string }) {
  const { likeCommentMutation, unLikeCommentMutation } = useCommentLikesMutations({ postId });

  const likeComment = ({ commentId }: { commentId: string }) => {
    likeCommentMutation.mutate({ commentId });
  };

  const unLikeComment = ({ commentId }: { commentId: string }) => {
    unLikeCommentMutation.mutate({ commentId });
  };

  return { likeComment, unLikeComment };
}
