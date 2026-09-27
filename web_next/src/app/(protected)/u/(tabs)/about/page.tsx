'use client';

import { Suspense } from 'react';
import { useUserQuery } from '@/hooks/queries/useUserQuery';
import { About } from './About';
import { useProfileId } from '../../useProfileId';

function AboutTab() {
  const { data: profile } = useUserQuery(useProfileId());
  if (!profile) return null;
  return (
    <div className="mt-1">
      <About profile={profile} />
    </div>
  );
}

export default function Page() {
  return (
    <Suspense>
      <AboutTab />
    </Suspense>
  );
}
