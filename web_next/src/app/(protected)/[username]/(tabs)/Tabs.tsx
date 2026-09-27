'use client';

import { TabButton } from '@/components/TabButton';
import { usePathname, useSelectedLayoutSegment } from 'next/navigation';
import { useLanguage } from '@/hooks/useLanguage';

export default function Tabs({ isOwnProfile }: { isOwnProfile: boolean }) {
  const selectedSegment = useSelectedLayoutSegment();
  const { t } = useLanguage();
  const parentLayoutSegment = `/${usePathname().split('/')[1]}`;

  return (
    <div className="mt-5 flex flex-row justify-around gap-3 overflow-x-auto border-b border-border/80">
      {[
        { title: t('动态', 'Posts'), segment: parentLayoutSegment },
        { title: t('媒体', 'Media'), segment: `${parentLayoutSegment}/photos` },
        {
          title: isOwnProfile ? t('收藏', 'Bookmarks') : t('简介', 'About'),
          segment: `${parentLayoutSegment}/${isOwnProfile ? 'bookmarks' : 'about'}`,
        },
        ...[isOwnProfile ? { title: t('互动', 'Activity'), segment: `${parentLayoutSegment}/activity` } : undefined],
      ].map((item) => {
        if (!item) return null;
        const { title, segment } = item;
        const isActive =
          (selectedSegment === null ? parentLayoutSegment : `${parentLayoutSegment}/${selectedSegment}`) === segment;
        return <TabButton key={segment} title={title} isActive={isActive} href={segment} />;
      })}
    </div>
  );
}
