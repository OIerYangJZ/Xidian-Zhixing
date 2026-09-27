import Button from '@/components/ui/Button';
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { AnimatePresence, motion } from 'framer-motion';
import { GetVisualMedia, DisplayIdentity, GetPost } from '@/types/definitions';
import { useWritePostMutations } from '@/hooks/mutations/useWritePostMutations';
import { useDialogs } from '@/hooks/useDialogs';
import { revokeVisualMediaObjectUrls } from '@/lib/revokeVisualMediaObjectUrls';
import { useLanguage } from '@/hooks/useLanguage';
import { getAnonymousAlias, getSectionTree } from '@/lib/backend/endpoints';
import { TextAreaWithMentionsAndHashTags } from './TextAreaWithMentionsAndHashTags';
import { GenericDialog } from './GenericDialog';
import { CreatePostSort } from './CreatePostSort';
import { ProfilePhotoOwn } from './ui/ProfilePhotoOwn';
import { CreatePostOptions } from './CreatePostOptions';

const GENERAL_SECTION = { sectionType: 'general', sectionId: 'general', sectionName: '综合' };
const MAX_IMAGES = 9;

export function CreatePostDialog({
  editingPost,
  shouldOpenFileInputOnMount,
  setShown,
}: {
  /** Set when editing: text and images change, identity and section do not. */
  editingPost: GetPost | null;
  shouldOpenFileInputOnMount: boolean;
  setShown: (isOpen: boolean) => void;
}) {
  const { t } = useLanguage();
  const isEditing = editingPost !== null;
  const [title, setTitle] = useState(editingPost?.title ?? '');
  const [content, setContent] = useState(editingPost?.content ?? '');
  const [visualMedia, setVisualMedia] = useState<GetVisualMedia[]>(editingPost?.visualMedia ?? []);
  const [displayIdentity, setDisplayIdentity] = useState<DisplayIdentity>(editingPost?.displayIdentity ?? 'USER');
  const [anonymousAlias, setAnonymousAlias] = useState(
    editingPost?.displayIdentity === 'ANONYMOUS' ? editingPost.authorAlias : '',
  );
  const [sectionId, setSectionId] = useState(editingPost?.sectionId ?? GENERAL_SECTION.sectionId);
  const { data: sectionTree } = useQuery({
    queryKey: ['sections', 'tree'],
    queryFn: getSectionTree,
    staleTime: 300000,
  });
  // Clubs publish through their managers only, so they are not offered here.
  const sections = useMemo(() => [...(sectionTree?.general ?? []), ...(sectionTree?.colleges ?? [])], [sectionTree]);
  const section = useMemo(() => {
    const picked = sections.find((item) => item.sectionId === sectionId);
    return picked
      ? { sectionType: picked.sectionType, sectionId: picked.sectionId, sectionName: picked.sectionName || picked.name }
      : GENERAL_SECTION;
  }, [sections, sectionId]);
  const exitCreatePostModal = useCallback(() => setShown(false), [setShown]);
  const draft = useMemo(
    () => ({ title, content, visualMedia, displayIdentity, anonymousAlias, section }),
    [title, content, visualMedia, displayIdentity, anonymousAlias, section],
  );
  const { createPostMutation, editPostMutation } = useWritePostMutations({
    draft,
    editing: editingPost,
    exitCreatePostModal,
  });
  const saving = createPostMutation.isPending || editPostMutation.isPending;

  useEffect(() => {
    // Offer a random alias the first time the author switches to anonymous.
    if (isEditing || displayIdentity !== 'ANONYMOUS' || anonymousAlias) return;
    getAnonymousAlias()
      .then(({ alias }) => setAnonymousAlias((current) => current || alias))
      .catch(() => {});
  }, [isEditing, displayIdentity, anonymousAlias]);
  const { confirm } = useDialogs();
  const inputFileRef = useRef<HTMLInputElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const handleVisualMediaChange: React.ChangeEventHandler<HTMLInputElement> = useCallback(async (e) => {
    const { files } = e.target;

    if (files === null) return;
    const filesArr = [...files].filter((file) => file.type.startsWith('image/'));
    const selectedVisualMedia: GetVisualMedia[] = filesArr.map((file) => ({
      type: file.type.startsWith('image/') ? 'PHOTO' : 'VIDEO',
      url: URL.createObjectURL(file),
    }));
    setVisualMedia((prev) => [...prev, ...selectedVisualMedia].slice(0, MAX_IMAGES));
    // Clear the file input
    e.target.value = '';
  }, []);

  const handleClickPostButton = useCallback(
    () => (isEditing ? editPostMutation.mutate() : createPostMutation.mutate()),
    [createPostMutation, editPostMutation, isEditing],
  );

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
    const changed = isEditing
      ? title !== editingPost.title ||
        content !== (editingPost.content ?? '') ||
        visualMedia.map((media) => media.url).join() !== editingPost.visualMedia.map((media) => media.url).join()
      : title !== '' || content !== '' || visualMedia.length > 0;
    if (changed) {
      confirmExit();
      return;
    }
    exit();
  }, [confirmExit, title, content, visualMedia, exit, isEditing, editingPost]);

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
      title={isEditing ? t('编辑动态', 'Edit post') : t('发布动态', 'Create post')}
      handleClose={handleClose}>
      <div className="mb-[18px] flex flex-row gap-3 px-4">
        <div className="h-11 w-11">
          <ProfilePhotoOwn />
        </div>
        <div className="flex flex-1 flex-col justify-center gap-2">
          <input
            value={title}
            onChange={(event) => setTitle(event.target.value.slice(0, 200))}
            placeholder={t('标题（选填）', 'Title (optional)')}
            aria-label={t('标题', 'Title')}
            className="w-full bg-transparent text-lg font-semibold text-foreground outline-none placeholder:text-muted-foreground"
          />
          <TextAreaWithMentionsAndHashTags
            content={content}
            setContent={setContent}
            placeholder={t('分享此刻，写下你的校园生活…', 'Share a moment from campus…')}
          />
        </div>
        <div>
          <Button onPress={handleClickPostButton} size="small" isDisabled={content.trim() === ''} loading={saving}>
            {isEditing ? t('保存', 'Save') : t('发布', 'Post')}
          </Button>
        </div>
      </div>
      <div className="border-t border-border px-4 py-3">
        <label className="flex items-center justify-between gap-3 text-sm">
          <span>{t('发布身份', 'Post as')}</span>
          <select
            aria-label={t('发布身份', 'Post as')}
            disabled={isEditing}
            value={displayIdentity}
            onChange={(event) => setDisplayIdentity(event.target.value as DisplayIdentity)}
            className="min-h-10 border border-border bg-background px-3 text-foreground">
            <option value="USER">{t('本人', 'Yourself')}</option>
            <option value="ANONYMOUS">{t('匿名同学', 'Anonymous student')}</option>
          </select>
        </label>
        <label className="mt-3 flex items-center justify-between gap-3 text-sm">
          <span>{t('发布到', 'Section')}</span>
          <select
            aria-label={t('发布到', 'Section')}
            disabled={isEditing}
            value={sectionId}
            onChange={(event) => setSectionId(event.target.value)}
            className="min-h-10 border border-border bg-background px-3 text-foreground">
            {sections.length === 0 && <option value={GENERAL_SECTION.sectionId}>{GENERAL_SECTION.sectionName}</option>}
            {sections.map((item) => (
              <option key={item.id} value={item.sectionId}>
                {item.sectionName || item.name}
              </option>
            ))}
          </select>
        </label>
        {displayIdentity === 'ANONYMOUS' && (
          <label className="mt-3 flex items-center justify-between gap-3 text-sm">
            <span>{t('匿名昵称', 'Anonymous name')}</span>
            <input
              value={anonymousAlias}
              disabled={isEditing}
              onChange={(event) => setAnonymousAlias(event.target.value.slice(0, 24))}
              aria-label={t('匿名昵称', 'Anonymous name')}
              className="min-h-10 w-40 border border-border bg-background px-3 text-foreground"
            />
          </label>
        )}
        {displayIdentity === 'ANONYMOUS' && (
          <p className="mt-2 text-xs text-muted-foreground">
            {t(
              '其他同学看不到作者身份；管理员仍可处理违规内容。发布后不能更改身份。',
              'Other students cannot see the author. Moderators can still review reports. The identity cannot change after posting.',
            )}
          </p>
        )}
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
