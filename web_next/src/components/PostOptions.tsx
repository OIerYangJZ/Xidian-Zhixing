'use client';

import { Item, Section } from 'react-stately';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useDialogs } from '@/hooks/useDialogs';
import { Key, useCallback } from 'react';
import { useDeletePostMutation } from '@/hooks/mutations/useDeletePostMutation';
import { useErrorNotifier } from '@/hooks/useErrorNotifier';
import { useLanguage } from '@/hooks/useLanguage';
import { setPostProgress } from '@/lib/backend/endpoints';
import type { PostProgress } from '@/types/definitions';
import { DropdownMenuButton } from './ui/DropdownMenuButton';

/**
 * The author's menu.  Published text and images cannot be edited on this
 * backend, so the options are the post's 进行中/已解决 status and deletion.
 */
export function PostOptions({ postId, progress }: { postId: string; progress: PostProgress }) {
  const { confirm } = useDialogs();
  const { deleteMutation } = useDeletePostMutation();
  const { notifyError } = useErrorNotifier();
  const qc = useQueryClient();
  const { t } = useLanguage();

  const progressMutation = useMutation({
    mutationFn: (next: PostProgress) => setPostProgress(postId, next),
    onSuccess: (post) => qc.setQueryData(['posts', postId], post),
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

  const handleOptionClick = useCallback(
    (key: Key) => {
      if (key === 'resolve') progressMutation.mutate('resolved');
      else if (key === 'reopen') progressMutation.mutate('ongoing');
      else handleDeleteClick();
    },
    [handleDeleteClick, progressMutation],
  );

  return (
    <DropdownMenuButton
      key={`posts-${postId}-options`}
      label={t('动态选项', 'Post options')}
      onAction={handleOptionClick}>
      <Section>
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
