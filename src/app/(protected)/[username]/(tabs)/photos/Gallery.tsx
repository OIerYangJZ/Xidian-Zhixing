'use client';

import { GetVisualMedia } from '@/types/definitions';
import { useVisualMediaModal } from '@/hooks/useVisualMediaModal';
import { GalleryItem } from './GalleryItem';

export function Gallery({ visualMedia }: { visualMedia: GetVisualMedia[] }) {
  const { showVisualMediaModal } = useVisualMediaModal();

  const openVisualMediaModal = (initialSlide: number) => () => {
    showVisualMediaModal({ visualMedia, initialSlide });
  };

  return (
    <div className="mt-1 grid grid-cols-3 gap-0.5 sm:gap-1">
      {visualMedia.map(({ type, url }, i) => (
        <GalleryItem key={url} type={type} url={url} onClick={openVisualMediaModal(i)} />
      ))}
    </div>
  );
}
