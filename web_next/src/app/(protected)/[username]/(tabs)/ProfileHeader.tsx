'use client';

import { ProfileActionButtons } from '@/components/ProfileActionButtons';
import { GetUser } from '@/types/definitions';
import { useUserQuery } from '@/hooks/queries/useUserQuery';
import Link from 'next/link';
import { Ellipse } from '@/svg_components';
import { ButtonLink } from '@/components/ui/ButtonLink';
import { useLanguage } from '@/hooks/useLanguage';
import Tabs from './Tabs';
import CoverPhoto from './CoverPhoto';
import ProfilePhoto from './ProfilePhoto';

export function ProfileHeader({
  isOwnProfile,
  initialProfileData,
}: {
  isOwnProfile: boolean;
  initialProfileData: GetUser;
}) {
  const { data } = useUserQuery(initialProfileData.id);
  const { t } = useLanguage();
  // If there is no query of the user data yet, use the
  // `initialProfileData` that was fetched on server.
  const profile = data || initialProfileData;

  return (
    <>
      <div className="relative mb-[72px] md:pt-4">
        <div className="h-52 overflow-hidden bg-muted/30">
          <CoverPhoto isOwnProfile={isOwnProfile} photoUrl={profile.coverPhoto} />
        </div>
        <ProfilePhoto isOwnProfile={isOwnProfile} photoUrl={profile.profilePhoto} name={initialProfileData.name!} />
        <div className="absolute -bottom-14 right-4 md:right-1">
          {isOwnProfile ? (
            <ButtonLink shape="pill" mode="subtle" href="/edit-profile">
              {t('编辑资料', 'Edit profile')}
            </ButtonLink>
          ) : (
            <ProfileActionButtons targetUserId={profile.id} />
          )}
        </div>
      </div>

      <div className="px-4 pt-1">
        <h1 className="text-2xl font-bold">{profile.name}</h1>
        <p className="mt-0.5 text-sm text-muted-foreground">@{profile.username}</p>
        {profile.bio && (
          <p className="mt-3 whitespace-pre-wrap text-[15px] leading-6 text-foreground/90">{profile.bio}</p>
        )}
        {!isOwnProfile && profile.showContactable && (
          <p className="mt-2 text-sm text-primary">{t('欢迎通过知行联系我', 'Open to being contacted on Zhixing')}</p>
        )}
        <div className="mt-3 flex flex-row items-center gap-3 text-sm">
          <Link
            href={`/${profile.username}/followers`}
            className="link"
            title={`${initialProfileData.name}&apos; followers`}>
            <span className="font-semibold">{profile.followerCount}</span>{' '}
            <span className="font-medium text-muted-foreground">{t('粉丝', 'Followers')}</span>
          </Link>
          <Ellipse className="h-1 w-1 fill-foreground" />
          <Link
            href={`/${profile.username}/following`}
            className="link"
            title={`${initialProfileData.name}&apos; followed users`}>
            <span className="font-semibold">{profile.followingCount}</span>{' '}
            <span className="font-medium text-muted-foreground">{t('关注', 'Following')}</span>
          </Link>
        </div>
        <Tabs isOwnProfile={isOwnProfile} />
      </div>
    </>
  );
}
