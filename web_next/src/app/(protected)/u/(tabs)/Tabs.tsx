'use client';

import { TabButton } from '@/components/TabButton';
import { usePathname } from 'next/navigation';
import { useLanguage } from '@/hooks/useLanguage';
import { profileHref } from '@/lib/profileHref';

export default function Tabs({ isOwnProfile, profileId }: { isOwnProfile: boolean; profileId: string }) {
  const { t } = useLanguage();
  const pathname = usePathname();

  const tabs = [
    { title: t('动态', 'Posts'), tab: undefined },
    { title: t('媒体', 'Media'), tab: 'photos' },
    isOwnProfile ? { title: t('收藏', 'Bookmarks'), tab: 'bookmarks' } : { title: t('简介', 'About'), tab: 'about' },
    // Your own history of likes, comments, reposts…: private, so own profile only.
    ...(isOwnProfile ? [{ title: t('互动', 'Activity'), tab: 'activity' }] : []),
  ];

  return (
    <div className="mt-5 flex flex-row justify-around gap-3 overflow-x-auto border-b border-border/80">
      {tabs.map(({ title, tab }) => {
        const isActive = pathname === (tab ? `/u/${tab}` : '/u');
        return <TabButton key={title} title={title} isActive={isActive} href={profileHref(profileId, tab)!} />;
      })}
    </div>
  );
}
