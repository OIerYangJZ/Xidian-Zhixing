'use client';

import { GetVisualMedia } from '@/types/definitions';
import { useVisualMediaModal } from '@/hooks/useVisualMediaModal';
import { useLanguage } from '@/hooks/useLanguage';
import { EmptyState } from '@/components/ui/EmptyState';
import { GalleryItem } from './GalleryItem';

export function Gallery({ visualMedia }: { visualMedia: GetVisualMedia[] }) {
  const { showVisualMediaModal } = useVisualMediaModal();
  const { t } = useLanguage();

  const openVisualMediaModal = (initialSlide: number) => () => {
    showVisualMediaModal({ visualMedia, initialSlide });
  };

  return (
    <div className="mt-1 grid grid-cols-3 gap-0.5 sm:gap-1">
      {visualMedia.length === 0 && (
        <EmptyState
          title={t('还没有照片或视频', 'No photos or videos yet')}
          description={t('发布带有图片或视频的动态后，它们会显示在这里。', 'Media from your posts will appear here.')}
          className="col-span-3"
        />
      )}
      {visualMedia.map(({ type, url }, i) => (
        <GalleryItem key={url} type={type} url={url} onClick={openVisualMediaModal(i)} />
      ))}
    </div>
  );
}
