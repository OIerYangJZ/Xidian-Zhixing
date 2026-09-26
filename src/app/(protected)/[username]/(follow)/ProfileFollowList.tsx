'use client';

import { DiscoverProfiles } from '@/components/DiscoverProfiles';
import { DiscoverSearch } from '@/components/DiscoverSearch';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';

export function ProfileFollowList({ profileId, mode }: { profileId?: string; mode: 'followers' | 'following' }) {
  const { t } = useLanguage();
  const isFollowers = mode === 'followers';
  const title = isFollowers ? t('粉丝', 'Followers') : t('关注', 'Following');

  return (
    <div>
      <PageHeader title={title} sticky />
      <div className="pt-4">
        <div className="px-4 sm:px-5">
          <DiscoverSearch label={isFollowers ? t('搜索粉丝', 'Search followers') : t('搜索关注', 'Search following')} />
        </div>
        <DiscoverProfiles {...(isFollowers ? { followersOf: profileId } : { followingOf: profileId })} />
      </div>
    </div>
  );
}
