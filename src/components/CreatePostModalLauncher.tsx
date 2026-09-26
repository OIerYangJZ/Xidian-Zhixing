'use client';

import { useCreatePostModal } from '@/hooks/useCreatePostModal';
import SvgImage from '@/svg_components/Image';
import { useCallback } from 'react';
import { ProfilePhotoOwn } from './ui/ProfilePhotoOwn';
import { ButtonNaked } from './ui/ButtonNaked';

export function CreatePostModalLauncher() {
  const { launchCreatePost } = useCreatePostModal();
  const launcCreatePostFinderClosed = useCallback(() => launchCreatePost({}), [launchCreatePost]);
  const launchCreatePostFinderOpened = useCallback(() => {
    launchCreatePost({
      shouldOpenFileInputOnMount: true,
    });
  }, [launchCreatePost]);

  return (
    <div className="border-b border-border/80 px-4 py-4 sm:px-5">
      <div className="flex flex-row items-center gap-3">
        <div className="h-10 w-10 flex-shrink-0">
          <ProfilePhotoOwn />
        </div>
        <ButtonNaked
          onPress={launcCreatePostFinderClosed}
          className="flex min-h-11 flex-grow items-center rounded-full bg-secondary/80 px-4 text-left transition hover:bg-secondary">
          <p className="text-[15px] text-muted-foreground">分享此刻，写下你的校园生活…</p>
        </ButtonNaked>
      </div>
      <div className="ml-[52px] mt-3 flex flex-row gap-2">
        <ButtonNaked
          onPress={launchCreatePostFinderOpened}
          className="group flex cursor-pointer flex-row items-center gap-2 rounded-full px-3 py-2 text-muted-foreground transition hover:bg-secondary">
          <SvgImage className="h-[18px] w-[18px] text-primary" />
          <p className="text-sm font-medium group-hover:text-foreground">图片 / 视频</p>
        </ButtonNaked>
        {/* <ButtonNaked className="group flex cursor-pointer flex-row items-center gap-4">
          <EmojiHappySmile stroke="black" width={24} height={24} />
          <p className="text-base font-semibold text-gray-500 group-hover:text-black">
            Mood
          </p>
        </ButtonNaked> */}
      </div>
    </div>
  );
}
