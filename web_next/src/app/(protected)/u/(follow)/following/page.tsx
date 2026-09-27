'use client';

import { Suspense } from 'react';
import { ProfileFollowList } from '../ProfileFollowList';
import { useProfileId } from '../../useProfileId';

function List() {
  return <ProfileFollowList profileId={useProfileId()} mode="following" />;
}

export default function Page() {
  return (
    <Suspense>
      <List />
    </Suspense>
  );
}
