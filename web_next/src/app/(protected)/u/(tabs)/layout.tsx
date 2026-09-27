'use client';

import React, { Suspense } from 'react';
import { useLanguage } from '@/hooks/useLanguage';
import { useUserQuery } from '@/hooks/queries/useUserQuery';
import { ProfileHeader } from './ProfileHeader';
import { useProfileId } from '../useProfileId';

function ProfileLayout({ children }: { children: React.ReactNode }) {
  const { t } = useLanguage();
  const profileId = useProfileId();
  const { data: profile, isPending, isError } = useUserQuery(profileId);

  if (!profileId || isError)
    return (
      <p className="px-4 py-6 text-sm text-muted-foreground">
        {t('这个用户不存在或已注销。', 'This user does not exist.')}
      </p>
    );
  if (isPending || !profile) return null;

  return (
    <div className="pb-0">
      <div className="pr-0 md:pr-4">
        <ProfileHeader profile={profile} />
      </div>
      <div className="px-4">{children}</div>
    </div>
  );
}

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense>
      <ProfileLayout>{children}</ProfileLayout>
    </Suspense>
  );
}
