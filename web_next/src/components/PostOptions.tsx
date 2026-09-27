'use client';

import { Item, Section } from 'react-stately';
import { useDialogs } from '@/hooks/useDialogs';
import { GetVisualMedia } from '@/types/definitions';
import { Key, useCallback } from 'react';
import { useCreatePostModal } from '@/hooks/useCreatePostModal';
import { useDeletePostMutation } from '@/hooks/mutations/useDeletePostMutation';
import { useLanguage } from '@/hooks/useLanguage';
import type { DisplayIdentity } from '@prisma/client';
import { DropdownMenuButton } from './ui/DropdownMenuButton';

export function PostOptions({
  postId,
  content,
  visualMedia,
  displayIdentity,
}: {
  postId: string;
  content: string | null;
  visualMedia?: GetVisualMedia[];
  displayIdentity: DisplayIdentity;
}) {
  const { confirm } = useDialogs();
  const { launchEditPost } = useCreatePostModal();
  const { deleteMutation } = useDeletePostMutation();
  const { t } = useLanguage();

  const handleDeleteClick = useCallback(() => {
    confirm({
      title: t('删除动态', 'Delete post'),
      message: t('确定删除这条动态吗？此操作无法撤销。', 'Delete this post? This cannot be undone.'),
      onConfirm: () => {
        // Wait for the dialog to close before deleting the comment to pass the focus to
        // the next element first, preventing the focus from resetting to the top
        setTimeout(() => deleteMutation.mutate({ postId }), 300);
      },
    });
  }, [confirm, deleteMutation, postId, t]);

  const handleEditClick = useCallback(() => {
    launchEditPost({
      postId,
      initialContent: content ?? '',
      initialVisualMedia: visualMedia ?? [],
      initialDisplayIdentity: displayIdentity,
    });
  }, [launchEditPost, postId, content, visualMedia, displayIdentity]);

  const handleOptionClick = useCallback(
    (key: Key) => {
      if (key === 'edit') {
        handleEditClick();
      } else {
        handleDeleteClick();
      }
    },
    [handleEditClick, handleDeleteClick],
  );

  return (
    <DropdownMenuButton
      key={`posts-${postId}-options`}
      label={t('动态选项', 'Post options')}
      onAction={handleOptionClick}>
      <Section>
        <Item key="edit">{t('编辑动态', 'Edit post')}</Item>
        <Item key="delete">{t('删除动态', 'Delete post')}</Item>
      </Section>
    </DropdownMenuButton>
  );
}
