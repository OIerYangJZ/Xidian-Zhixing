'use client';

import { TabButton } from '@/components/TabButton';
import { usePathname, useSelectedLayoutSegment } from 'next/navigation';

export default function Tabs({ isOwnProfile }: { isOwnProfile: boolean }) {
  const selectedSegment = useSelectedLayoutSegment();
  const parentLayoutSegment = `/${usePathname().split('/')[1]}`;

  return (
    <div className="mt-5 flex flex-row justify-around gap-3 overflow-x-auto border-b border-border/80">
      {[
        { title: '动态', segment: parentLayoutSegment },
        { title: '媒体', segment: `${parentLayoutSegment}/photos` },
        {
          title: isOwnProfile ? '收藏' : '简介',
          segment: `${parentLayoutSegment}/${isOwnProfile ? 'bookmarks' : 'about'}`,
        },
        ...[isOwnProfile ? { title: '互动', segment: `${parentLayoutSegment}/activity` } : undefined],
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
