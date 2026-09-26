import { Item, Section } from 'react-stately';
import { useDialogs } from '@/hooks/useDialogs';
import { GetVisualMedia } from '@/types/definitions';
import { Key, useCallback } from 'react';
import { useCreatePostModal } from '@/hooks/useCreatePostModal';
import { useDeletePostMutation } from '@/hooks/mutations/useDeletePostMutation';
import { DropdownMenuButton } from './ui/DropdownMenuButton';

export function PostOptions({
  postId,
  content,
  visualMedia,
}: {
  postId: number;
  content: string | null;
  visualMedia?: GetVisualMedia[];
}) {
  const { confirm } = useDialogs();
  const { launchEditPost } = useCreatePostModal();
  const { deleteMutation } = useDeletePostMutation();

  const handleDeleteClick = useCallback(() => {
    confirm({
      title: '删除动态',
      message: '确定删除这条动态吗？此操作无法撤销。',
      onConfirm: () => {
        // Wait for the dialog to close before deleting the comment to pass the focus to
        // the next element first, preventing the focus from resetting to the top
        setTimeout(() => deleteMutation.mutate({ postId }), 300);
      },
    });
  }, [confirm, deleteMutation, postId]);

  const handleEditClick = useCallback(() => {
    launchEditPost({
      postId,
      initialContent: content ?? '',
      initialVisualMedia: visualMedia ?? [],
    });
  }, [launchEditPost, postId, content, visualMedia]);

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
    <DropdownMenuButton key={`posts-${postId}-options`} label="动态选项" onAction={handleOptionClick}>
      <Section>
        <Item key="edit">编辑动态</Item>
        <Item key="delete">删除动态</Item>
      </Section>
    </DropdownMenuButton>
  );
}
