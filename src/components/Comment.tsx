'use client';

import { GetComment } from '@/types/definitions';
import { memo, useEffect, useCallback, Key } from 'react';
import { isEqual } from 'lodash';
import SvgHeart from '@/svg_components/Heart';
import SvgArrowReply from '@/svg_components/ArrowReply';
import { useSearchParams } from 'next/navigation';
import { useDialogs } from '@/hooks/useDialogs';
import { Item, Section } from 'react-stately';
import { useCreateCommentMutations } from '@/hooks/mutations/useCreateCommentMutations';
import { useUpdateDeleteComments } from '@/hooks/useUpdateDeleteComments';
import { useLikeUnlikeComments } from '@/hooks/useLikeUnlikeComments';
import { useLanguage } from '@/hooks/useLanguage';
import { useToast } from '@/hooks/useToast';
import { QueryKey } from '@tanstack/react-query';
import { ProfilePhoto } from './ui/ProfilePhoto';
import { ButtonNaked } from './ui/ButtonNaked';
import { DropdownMenuButton } from './ui/DropdownMenuButton';
import Button from './ui/Button';
import { CommentReplies } from './CommentReplies';
import { CommentContent } from './CommentContent';
import { ToggleStepper } from './ui/ToggleStepper';

export const Comment = memo(
  ({
    id: commentId,
    content,
    createdAt,
    user: author,
    isOwnComment,
    isLiked,
    _count,
    repliesShown,
    setRepliesVisibility,
    queryKey,
  }: GetComment & {
    isOwnComment: boolean;
    setRepliesVisibility: (params: { commentId: number; shown: boolean }) => void;
    queryKey: QueryKey;
  }) => {
    const numberOfLikes = _count.commentLikes;
    const { t } = useLanguage();
    const numberOfReplies = _count.replies;
    const { prompt } = useDialogs();
    const { showToast } = useToast();
    const { createReplyMutation } = useCreateCommentMutations();
    const { handleEdit, handleDelete } = useUpdateDeleteComments({ queryKey });
    const { likeComment, unLikeComment } = useLikeUnlikeComments({ queryKey });

    const searchParams = useSearchParams();
    // Highlight comment if the `commentId` is equal to the `comment-id` search param
    const shouldHighlight = searchParams.get('comment-id') === commentId.toString();

    const toggleReplies = useCallback(
      () => setRepliesVisibility({ commentId, shown: !repliesShown }),
      [commentId, repliesShown, setRepliesVisibility],
    );
    const handleCreateReply = useCallback(() => {
      prompt({
        title: t('回复评论', 'Reply to comment'),
        message: t(`你正在回复 ${author.name} 的评论。`, `You are replying to ${author.name}'s comment.`),
        promptType: 'textarea',
        onSubmit: (value) => {
          createReplyMutation.mutate(
            {
              parentId: commentId,
              content: value,
            },
            {
              onSuccess: () => !repliesShown && toggleReplies(),
            },
          );
        },
      });
    }, [author.name, commentId, createReplyMutation, prompt, repliesShown, toggleReplies, t]);
    const handleLikeToggle = useCallback(
      (isSelected: boolean) => (isSelected ? likeComment({ commentId }) : unLikeComment({ commentId })),
      [commentId, likeComment, unLikeComment],
    );
    const reportComment = () => {
      prompt({
        title: t('举报评论', 'Report comment'),
        message: t('请简要说明举报原因，管理员会查看。', 'Briefly explain the reason for your report.'),
        promptType: 'textarea',
        onSubmit: async (details) => {
          const response = await fetch('/api/reports', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ commentId, reason: 'OTHER', details }),
          });
          showToast({
            title: response.ok ? t('举报已提交', 'Report submitted') : t('举报失败', 'Could not report'),
            type: response.ok ? 'success' : 'error',
          });
        },
      });
    };
    const onDropdownAction = useCallback(
      (key: Key) => {
        if (key === 'edit') {
          handleEdit({ commentId, content });
        } else {
          handleDelete({ commentId });
        }
      },
      [commentId, content, handleDelete, handleEdit],
    );

    // Show the replies if the comment to be highlighted is a reply to this comment
    useEffect(() => {
      setTimeout(() => {
        const shouldOpenRepliesOnMount = searchParams.get('comment-parent-id') === commentId.toString();
        if (shouldOpenRepliesOnMount) setRepliesVisibility({ commentId, shown: true });
      }, 1000);
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    return (
      <div className="relative flex gap-3 before:absolute before:bottom-0 before:left-5 before:top-11 before:w-px before:bg-border">
        <div className="relative z-[1] h-10 w-10 flex-shrink-0 rounded-full bg-background">
          <ProfilePhoto name={author.name} username={author.username} photoUrl={author.profilePhoto} />
        </div>

        <div className="min-w-0 flex-1">
          <CommentContent
            name={author.name}
            username={author.username}
            content={content}
            createdAt={createdAt}
            shouldHighlight={shouldHighlight}
          />

          <div className="flex gap-2">
            <ToggleStepper
              isSelected={isLiked}
              aria-label={isLiked ? t('取消评论点赞', 'Unlike comment') : t('点赞评论', 'Like comment')}
              onChange={handleLikeToggle}
              Icon={SvgHeart}
              quantity={numberOfLikes}
            />
            <Button
              onPress={handleCreateReply}
              Icon={SvgArrowReply}
              loading={createReplyMutation.isPending}
              mode="ghost"
            />
            {!isOwnComment && (
              <button
                type="button"
                onClick={reportComment}
                className="px-2 text-xs text-muted-foreground hover:text-destructive">
                {t('举报', 'Report')}
              </button>
            )}

            {isOwnComment && (
              <DropdownMenuButton
                key={`comments-${commentId}-options`}
                label={t('评论选项', 'Comment options')}
                onAction={onDropdownAction}>
                <Section>
                  <Item key="edit">{t('编辑评论', 'Edit comment')}</Item>
                  <Item key="delete">{t('删除评论', 'Delete comment')}</Item>
                </Section>
              </DropdownMenuButton>
            )}
          </div>

          {repliesShown && (
            <div className="ml-5 mt-1 border-l border-border pl-3">
              <CommentReplies parentId={commentId} />
            </div>
          )}
          {numberOfReplies !== 0 && (
            <ButtonNaked
              onPress={toggleReplies}
              className="my-1 cursor-pointer text-sm font-semibold text-muted-foreground hover:text-muted-foreground/70">
              {!repliesShown
                ? t(`查看 ${numberOfReplies} 条回复`, `View ${numberOfReplies} replies`)
                : t('收起回复', 'Hide replies')}
            </ButtonNaked>
          )}
        </div>
      </div>
    );
  },
  (oldProps, newProps) => isEqual(oldProps, newProps),
);

Comment.displayName = 'Comment';
