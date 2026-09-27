'use client';

import { memo, useCallback } from 'react';
import { isEqual } from 'lodash';
import SvgHeart from '@/svg_components/Heart';
import SvgArrowReply from '@/svg_components/ArrowReply';
import { useSearchParams } from 'next/navigation';
import { Item, Section } from 'react-stately';
import { useLanguage } from '@/hooks/useLanguage';
import { useDialogs } from '@/hooks/useDialogs';
import { useReportDialog } from '@/hooks/useReportDialog';
import { useCreateCommentMutations } from '@/hooks/mutations/useCreateCommentMutations';
import { useUpdateDeleteComments } from '@/hooks/useUpdateDeleteComments';
import { useLikeUnlikeComments } from '@/hooks/useLikeUnlikeComments';
import type { CommentReplyItem } from '@/lib/commentThreads';
import { ToggleStepper } from './ui/ToggleStepper';
import { CommentContent } from './CommentContent';
import { DropdownMenuButton } from './ui/DropdownMenuButton';
import { ProfilePhoto } from './ui/ProfilePhoto';
import Button from './ui/Button';

export const CommentReply = memo(
  ({
    id: commentId,
    postId,
    content,
    createdAt,
    user: author,
    isOwnComment,
    isPostAuthor,
    isPending,
    isLiked,
    replyToName,
    _count,
  }: CommentReplyItem) => {
    const { t } = useLanguage();
    const { prompt } = useDialogs();
    const { openReport } = useReportDialog();
    const { createCommentMutation } = useCreateCommentMutations();
    const { handleDelete } = useUpdateDeleteComments({ postId });
    const { likeComment, unLikeComment } = useLikeUnlikeComments({ postId });

    const handleLikeClick = useCallback(
      () => (!isLiked ? likeComment({ commentId }) : unLikeComment({ commentId })),
      [isLiked, likeComment, unLikeComment, commentId],
    );
    const handleReply = useCallback(() => {
      prompt({
        title: t('回复', 'Reply'),
        message: t(`你正在回复 ${author.name}。`, `You are replying to ${author.name}.`),
        promptType: 'textarea',
        onSubmit: (value) => createCommentMutation.mutate({ postId, parentId: commentId, content: value }),
      });
    }, [author.name, commentId, createCommentMutation, postId, prompt, t]);

    const searchParams = useSearchParams();
    // Highlight the comment a notification linked to (postHref's `comment` param)
    const shouldHighlight = searchParams.get('comment') === commentId;

    return (
      <div className="mt-3 flex gap-3">
        <div className="h-9 w-9 flex-shrink-0">
          <ProfilePhoto name={author.name} username={author.username} photoUrl={author.profilePhoto} />
        </div>

        <div className="min-w-0 flex-1">
          <CommentContent
            name={author.name}
            username={author.username}
            content={content}
            createdAt={createdAt}
            shouldHighlight={shouldHighlight}
            isPostAuthor={isPostAuthor}
            isPending={isPending}
            replyToName={replyToName}
          />

          <div className="flex origin-left items-center gap-1">
            <ToggleStepper
              isSelected={isLiked}
              aria-label={isLiked ? t('取消回复点赞', 'Unlike reply') : t('点赞回复', 'Like reply')}
              onPress={handleLikeClick}
              Icon={SvgHeart}
              quantity={_count.commentLikes}
            />
            <Button
              onPress={handleReply}
              Icon={SvgArrowReply}
              loading={createCommentMutation.isPending}
              mode="ghost"
              aria-label={t('回复', 'Reply')}
            />
            {!isOwnComment && (
              <button
                type="button"
                onClick={() => openReport({ targetType: 'comment', targetId: commentId })}
                className="px-2 text-xs text-muted-foreground hover:text-destructive">
                {t('举报', 'Report')}
              </button>
            )}
            {isOwnComment && (
              <DropdownMenuButton
                key={`replies-${commentId}-options`}
                label={t('回复选项', 'Reply options')}
                onAction={() => handleDelete({ commentId })}>
                <Section>
                  <Item key="delete">{t('删除回复', 'Delete reply')}</Item>
                </Section>
              </DropdownMenuButton>
            )}
          </div>
        </div>
      </div>
    );
  },
  (oldProps, newProps) => isEqual(oldProps, newProps),
);

CommentReply.displayName = 'CommentReply';
