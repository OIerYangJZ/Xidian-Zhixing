'use client';

import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { PageHeader } from '@/components/ui/PageHeader';
import { TextInput } from '@/components/ui/TextInput';
import { ProfilePhoto } from '@/components/ui/ProfilePhoto';
import { ProfileActionButtons } from '@/components/ProfileActionButtons';
import { GenericLoading } from '@/components/GenericLoading';
import { SomethingWentWrong } from '@/components/SometingWentWrong';
import SvgSearch from '@/svg_components/Search';
import Link from 'next/link';
import { useLanguage } from '@/hooks/useLanguage';
import { useSession } from '@/lib/backend/session';
import { listMyFollowers, listMyFollowing } from '@/lib/backend/endpoints';
import { profileHref } from '@/lib/profileHref';

/**
 * The signed-in user's own followers / following.  The backend has no such
 * list for other people, so another user's id shows a notice instead.
 */
export function ProfileFollowList({ profileId, mode }: { profileId: string; mode: 'followers' | 'following' }) {
  const { t } = useLanguage();
  const { data: session } = useSession();
  const [filter, setFilter] = useState('');
  const isFollowers = mode === 'followers';
  const isOwn = !!session && session.user.id === profileId;
  const { data, isPending, isError } = useQuery({
    queryKey: ['users', 'me', mode],
    queryFn: isFollowers ? listMyFollowers : listMyFollowing,
    enabled: isOwn,
  });
  const rows = useMemo(
    () => (data ?? []).filter((row) => row.nickname.toLowerCase().includes(filter.trim().toLowerCase())),
    [data, filter],
  );
  const title = isFollowers ? t('粉丝', 'Followers') : t('关注', 'Following');

  return (
    <div>
      <PageHeader title={title} sticky />
      <div className="px-4 pt-4 sm:px-5">
        {!isOwn ? (
          <p className="py-6 text-sm text-muted-foreground">{t('只能查看自己的关注和粉丝列表。', 'Only your own lists can be viewed.')}</p>
        ) : isPending ? (
          <GenericLoading>{t('正在加载', 'Loading')}</GenericLoading>
        ) : isError ? (
          <SomethingWentWrong />
        ) : (
          <>
            <div className="mb-3">
              <TextInput
                onChange={setFilter}
                label={isFollowers ? t('搜索粉丝', 'Search followers') : t('搜索关注', 'Search following')}
                Icon={SvgSearch}
              />
            </div>
            {rows.length === 0 && <p className="py-4 text-sm text-muted-foreground">{t('这里还没有人。', 'No one here yet.')}</p>}
            {rows.map((row) => (
              <article key={row.userId} className="feed-separator flex items-center gap-3 border-b py-3">
                <div className="h-11 w-11 shrink-0">
                  <ProfilePhoto name={row.nickname} username={row.userId} photoUrl={row.avatarUrl || null} />
                </div>
                <Link href={profileHref(row.userId)!} className="min-w-0 flex-1 truncate text-sm font-semibold hover:underline">
                  {row.nickname}
                </Link>
                <ProfileActionButtons targetUserId={row.userId} />
              </article>
            ))}
          </>
        )}
      </div>
    </div>
  );
}
