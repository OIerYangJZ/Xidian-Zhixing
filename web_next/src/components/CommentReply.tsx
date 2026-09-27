'use client';

import { GetComment } from '@/types/definitions';
import { Key, memo, useCallback } from 'react';
import { isEqual } from 'lodash';
import SvgHeart from '@/svg_components/Heart';
import { useSearchParams } from 'next/navigation';
import { Item, Section } from 'react-stately';
import { useLanguage } from '@/hooks/useLanguage';
import { ToggleStepper } from './ui/ToggleStepper';
import { CommentContent } from './CommentContent';
import { DropdownMenuButton } from './ui/DropdownMenuButton';
import { ProfilePhoto } from './ui/ProfilePhoto';

export const CommentReply = memo(
  ({
    id: commentId,
    content,
    createdAt,
    user: author,
    isOwnReply,
    isLiked,
    _count,
    handleEdit,
    handleDelete,
    likeComment,
    unLikeComment,
  }: GetComment & {
    isOwnReply: boolean;
    handleEdit: (params: { commentId: string; content: string }) => void;
    handleDelete: (params: { commentId: string }) => void;
    likeComment: (params: { commentId: string }) => void;
    unLikeComment: (params: { commentId: string }) => void;
  }) => {
    const numberOfLikes = _count.commentLikes;
    const { t } = useLanguage();
    const handleLikeClick = useCallback(
      () => (!isLiked ? likeComment({ commentId }) : unLikeComment({ commentId })),
      [isLiked, likeComment, unLikeComment, commentId],
    );
    const onDropdownAction = useCallback(
      (key: Key) => {
        if (key === 'edit') {
          handleEdit({ commentId, content });
        } else {
          handleDelete({ commentId });
        }
      },
      [handleEdit, handleDelete, commentId, content],
    );

    const searchParams = useSearchParams();
    // Highlight comment if the `commentId` is equal to the `comment-id` search param
    const shouldHighlight = searchParams.get('comment-id') === commentId.toString();

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
          />

          <div className="flex origin-left">
            <ToggleStepper
              isSelected={isLiked}
              aria-label={isLiked ? t('取消回复点赞', 'Unlike reply') : t('点赞回复', 'Like reply')}
              onPress={handleLikeClick}
              Icon={SvgHeart}
              quantity={numberOfLikes}
            />
            {isOwnReply && (
              <DropdownMenuButton
                key={`replies-${commentId}-options`}
                label={t('回复选项', 'Reply options')}
                onAction={onDropdownAction}>
                <Section>
                  <Item key="edit">{t('编辑回复', 'Edit reply')}</Item>
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
