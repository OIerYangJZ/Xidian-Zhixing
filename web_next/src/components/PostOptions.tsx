'use client';

import { Item, Section } from 'react-stately';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useDialogs } from '@/hooks/useDialogs';
import { Key, useCallback } from 'react';
import { useDeletePostMutation } from '@/hooks/mutations/useDeletePostMutation';
import { useErrorNotifier } from '@/hooks/useErrorNotifier';
import { useLanguage } from '@/hooks/useLanguage';
import { getPost, setPostProgress } from '@/lib/backend/endpoints';
import { POST_PROGRESS_OPTIONS, type GetPost, type PostProgress } from '@/types/definitions';
import { useCreatePostModal } from '@/hooks/useCreatePostModal';
import { DropdownMenuButton } from './ui/DropdownMenuButton';

/** The author's menu: edit, 状态 (any of the four, in any order), delete. */
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
      else if (typeof key === 'string' && key.startsWith('progress:')) {
        progressMutation.mutate(key.slice('progress:'.length) as PostProgress);
      } else handleDeleteClick();
    },
    [handleDeleteClick, handleEditClick, progressMutation],
  );

  return (
    <DropdownMenuButton
      key={`posts-${postId}-options`}
      label={t('动态选项', 'Post options')}
      onAction={handleOptionClick}>
      {/* One array: a Section takes elements or an array, not a mix. */}
      <Section>
        {[
          <Item key="edit">{t('编辑动态', 'Edit post')}</Item>,
          ...POST_PROGRESS_OPTIONS.filter((option) => option.value !== progress).map((option) => (
            <Item key={`progress:${option.value}`}>
              {option.value === 'none'
                ? t('取消状态标记', 'Clear status')
                : t(`标记为${option.zh}`, `Mark as ${option.en.toLowerCase()}`)}
            </Item>
          )),
          <Item key="delete">{t('删除动态', 'Delete post')}</Item>,
        ]}
      </Section>
    </DropdownMenuButton>
  );
}
