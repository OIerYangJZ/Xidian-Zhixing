import Button from '@/components/ui/Button';
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { GetVisualMedia } from '@/types/definitions';
import { useWritePostMutations } from '@/hooks/mutations/useWritePostMutations';
import { useDialogs } from '@/hooks/useDialogs';
import { revokeVisualMediaObjectUrls } from '@/lib/revokeVisualMediaObjectUrls';
import { ToEditValues } from '@/lib/createPost';
import { useLanguage } from '@/hooks/useLanguage';
import { TextAreaWithMentionsAndHashTags } from './TextAreaWithMentionsAndHashTags';
import { GenericDialog } from './GenericDialog';
import { CreatePostSort } from './CreatePostSort';
import { ProfilePhotoOwn } from './ui/ProfilePhotoOwn';
import { CreatePostOptions } from './CreatePostOptions';

export function CreatePostDialog({
  toEditValues,
  shouldOpenFileInputOnMount,
  setShown,
}: {
  toEditValues: ToEditValues | null;
  shouldOpenFileInputOnMount: boolean;
  setShown: (isOpen: boolean) => void;
}) {
  const { t } = useLanguage();
  const mode: 'create' | 'edit' = toEditValues === null ? 'create' : 'edit';
  const [content, setContent] = useState(toEditValues?.initialContent || '');
  const [visualMedia, setVisualMedia] = useState<GetVisualMedia[]>(toEditValues?.initialVisualMedia ?? []);
  const exitCreatePostModal = useCallback(() => setShown(false), [setShown]);
  const { createPostMutation, updatePostMutation } = useWritePostMutations({
    content,
    visualMedia,
    exitCreatePostModal,
  });
  const { confirm } = useDialogs();
  const inputFileRef = useRef<HTMLInputElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const handleVisualMediaChange: React.ChangeEventHandler<HTMLInputElement> = useCallback(async (e) => {
    const { files } = e.target;

    if (files === null) return;
    const filesArr = [...files];
    const selectedVisualMedia: GetVisualMedia[] = filesArr.map((file) => ({
      type: file.type.startsWith('image/') ? 'PHOTO' : 'VIDEO',
      url: URL.createObjectURL(file),
    }));
    setVisualMedia((prev) => [...prev, ...selectedVisualMedia]);
    // Clear the file input
    e.target.value = '';
  }, []);

  const handleClickPostButton = useCallback(() => {
    if (mode === 'create') {
      createPostMutation.mutate();
    } else {
      if (!toEditValues) return;
      updatePostMutation.mutate({ postId: toEditValues.postId });
    }
  }, [createPostMutation, mode, toEditValues, updatePostMutation]);

  const exit = useCallback(() => {
    exitCreatePostModal();
    // Revoke the object URL's when exiting the create post dialog
    revokeVisualMediaObjectUrls(visualMedia);
  }, [exitCreatePostModal, visualMedia]);

  const confirmExit = useCallback(() => {
    confirm({
      title: t('保留未发布内容？', 'Discard this draft?'),
      message: t('退出后，这条动态的草稿会被丢弃。', 'Leaving will discard this post draft.'),
      onConfirm: () => setTimeout(() => exit(), 300),
    });
  }, [confirm, exit, t]);

  const handleClose = useCallback(() => {
    if (mode === 'create') {
      if (content !== '' || visualMedia.length > 0) {
        confirmExit();
        return;
      }
    } else if (mode === 'edit') {
      if (content !== toEditValues?.initialContent || visualMedia !== toEditValues.initialVisualMedia) {
        confirmExit();
        return;
      }
    }
    exit();
  }, [confirmExit, content, visualMedia, mode, toEditValues, exit]);

  const sortVariants = useMemo(
    () => ({
      initial: { height: 0 },
      animate: { height: 'auto' },
      exit: { height: 0 },
    }),
    [],
  );

  useEffect(() => {
    if (inputFileRef.current === null) return;
    if (shouldOpenFileInputOnMount) inputFileRef.current.click();
  }, [shouldOpenFileInputOnMount]);

  useEffect(() => {
    if (textareaRef.current === null) return;
    textareaRef.current.focus();
  }, []);

  useEffect(() => {
    const onEscPressed = (e: KeyboardEvent) => {
      if (e.key === 'Escape') handleClose();
    };

    document.addEventListener('keydown', onEscPressed, false);
    return () => {
      document.removeEventListener('keydown', onEscPressed, false);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <GenericDialog
      title={mode === 'create' ? t('发布动态', 'Create post') : t('编辑动态', 'Edit post')}
      handleClose={handleClose}>
      <div className="mb-[18px] flex flex-row gap-3 px-4">
        <div className="h-11 w-11">
          <ProfilePhotoOwn />
        </div>
        <div className="flex flex-1 flex-col justify-center">
          <TextAreaWithMentionsAndHashTags
            content={content}
            setContent={setContent}
            placeholder={t('分享此刻，写下你的校园生活…', 'Share a moment from campus…')}
          />
        </div>
        <div>
          <Button
            onPress={handleClickPostButton}
            size="small"
            isDisabled={content === '' && visualMedia.length === 0}
            loading={createPostMutation.isPending || updatePostMutation.isPending}>
            {mode === 'create' ? t('发布', 'Post') : t('保存', 'Save')}
          </Button>
        </div>
      </div>
      <CreatePostOptions handleVisualMediaChange={handleVisualMediaChange} ref={inputFileRef} />
      <AnimatePresence>
        {visualMedia.length > 0 && (
          <motion.div
            variants={sortVariants}
            initial="initial"
            animate="animate"
            exit="exit"
            className="overflow-hidden">
            <CreatePostSort visualMedia={visualMedia} setVisualMedia={setVisualMedia} />
          </motion.div>
        )}
      </AnimatePresence>
    </GenericDialog>
  );
}
