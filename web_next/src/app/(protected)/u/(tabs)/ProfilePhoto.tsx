'use client';

import Button from '@/components/ui/Button';
import { Avatar } from '@/components/ui/Avatar';
import { useUpdateProfileAndCoverPhotoClient } from '@/hooks/useUpdateProfileAndCoverPhotoClient';
import { useVisualMediaModal } from '@/hooks/useVisualMediaModal';
import { Camera } from '@/svg_components';
import { useCallback } from 'react';

export default function ProfilePhoto({
  isOwnProfile,
  name,
  photoUrl,
}: {
  isOwnProfile: boolean;
  name: string;
  photoUrl: string | null;
}) {
  const { inputFileRef, openInput, handleChange, isPending } = useUpdateProfileAndCoverPhotoClient('profile');
  const { showVisualMediaModal } = useVisualMediaModal();
  const showProfilePhotoModal = useCallback(() => {
    showVisualMediaModal({
      visualMedia: [
        {
          type: 'PHOTO',
          url: photoUrl as string,
        },
      ],
      initialSlide: 0,
    });
  }, [photoUrl, showVisualMediaModal]);

  return (
    <div className="absolute bottom-[-72px] left-4 h-36 w-36 rounded-[26%] border-4 border-background bg-background">
      <div className="absolute inset-0">
        <Avatar name={name} photoUrl={photoUrl} />
      </div>
      {photoUrl && (
        <button
          type="button"
          aria-label="Open profile photo"
          onClick={showProfilePhotoModal}
          className="absolute h-full w-full cursor-pointer rounded-[24%] bg-black/30 opacity-0 active:opacity-100"
        />
      )}
      {isOwnProfile && (
        <label>
          <div className="absolute bottom-0 right-0">
            <input
              type="file"
              name="file"
              ref={inputFileRef}
              onChange={handleChange}
              className="hidden"
              accept="image/png, image/jpg, image/jpeg"
            />
            <Button Icon={Camera} onPress={openInput} size="small" loading={isPending} />
          </div>
        </label>
      )}
    </div>
  );
}
