'use client';

import { Item, Section } from 'react-stately';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useDialogs } from '@/hooks/useDialogs';
import { Key, useCallback } from 'react';
import { useDeletePostMutation } from '@/hooks/mutations/useDeletePostMutation';
import { useErrorNotifier } from '@/hooks/useErrorNotifier';
import { useLanguage } from '@/hooks/useLanguage';
import { getPost, setPostProgress } from '@/lib/backend/endpoints';
import type { GetPost, PostProgress } from '@/types/definitions';
import { useCreatePostModal } from '@/hooks/useCreatePostModal';
import { DropdownMenuButton } from './ui/DropdownMenuButton';

/** The author's menu: edit, 进行中/已解决 status, delete. */
export function PostOptions({ post }: { post: GetPost }) {
  const { id: postId, progress } = post;
  const { launchEditPost } = useCreatePostModal();
  const { confirm } = useDialogs();
  const { deleteMutation } = useDeletePostMutation();
  const { notifyError } = useErrorNotifier();
  const qc = useQueryClient();
  const { t } = useLanguage();

  const progressMutation = useMutation({
    mutationFn: (next: PostProgress) => setPostProgress(postId, next),
    onSuccess: (updated) => qc.setQueryData(['posts', postId], updated),
    onError: (error) => notifyError(error, t('更新失败', 'Update failed')),
  });

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

  const handleEditClick = useCallback(async () => {
    // Lists leave out images still in review; the author's own GET includes
    // them, and the editor must start from the full set.
    try {
      launchEditPost(await getPost(postId));
    } catch (error) {
      notifyError(error, t('无法打开编辑', 'Could not open the editor'));
    }
  }, [launchEditPost, notifyError, postId, t]);

  const handleOptionClick = useCallback(
    (key: Key) => {
      if (key === 'edit') handleEditClick();
      else if (key === 'resolve') progressMutation.mutate('resolved');
      else if (key === 'reopen') progressMutation.mutate('ongoing');
      else handleDeleteClick();
    },
    [handleDeleteClick, handleEditClick, progressMutation],
  );

  return (
    <DropdownMenuButton
      key={`posts-${postId}-options`}
      label={t('动态选项', 'Post options')}
      onAction={handleOptionClick}>
      <Section>
        <Item key="edit">{t('编辑动态', 'Edit post')}</Item>
        {progress === 'ongoing' ? (
          <Item key="resolve">{t('标记为已解决', 'Mark as resolved')}</Item>
        ) : (
          <Item key="reopen">{t('重新标记为进行中', 'Mark as ongoing')}</Item>
        )}
        <Item key="delete">{t('删除动态', 'Delete post')}</Item>
      </Section>
    </DropdownMenuButton>
  );
}
