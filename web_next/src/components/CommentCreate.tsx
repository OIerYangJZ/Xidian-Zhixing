'use client';

import SvgSend from '@/svg_components/Send';
import { useCallback, useState } from 'react';
import { useCreateCommentMutations } from '@/hooks/mutations/useCreateCommentMutations';
import { useLanguage } from '@/hooks/useLanguage';
import Button from './ui/Button';
import { ProfilePhotoOwn } from './ui/ProfilePhotoOwn';
import { TextAreaWithMentionsAndHashTags } from './TextAreaWithMentionsAndHashTags';

export function CommentCreate({ postId }: { postId: number }) {
  const { t } = useLanguage();
  const [content, setContent] = useState('');
  const { createCommentMutation } = useCreateCommentMutations();

  const handleCreate = useCallback(() => {
    createCommentMutation.mutate(
      { postId, content },
      {
        onSuccess: () => {
          setContent('');
        },
      },
    );
  }, [content, createCommentMutation, postId]);

  return (
    <div className="feed-separator mt-2 border-t py-4">
      <div className="flex items-start gap-3">
        <div className="h-10 w-10 shrink-0">
          <ProfilePhotoOwn />
        </div>
        <div className="flex flex-1 flex-col justify-center">
          <TextAreaWithMentionsAndHashTags
            content={content}
            setContent={setContent}
            placeholder={t('写下你的评论…', 'Write a reply…')}
            shouldFocusOnMount={false}
          />
        </div>
        <div className="self-end">
          <Button
            onPress={handleCreate}
            mode="ghost"
            size="small"
            isDisabled={content === ''}
            loading={createCommentMutation.isPending}
            Icon={SvgSend}
          />
        </div>
      </div>
    </div>
  );
}
