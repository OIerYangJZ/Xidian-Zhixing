'use client';

import { Suspense } from 'react';
import { Posts } from '@/components/Posts';
import { useSession } from '@/lib/backend/session';
import { useProfileId } from '../../useProfileId';

function Bookmarks() {
  const profileId = useProfileId();
  const { data: session } = useSession();
  // Favorites are private: only the owner has this tab.
  if (!session || session.user.id !== profileId) return null;
  return <Posts type="bookmarks" userId={session.user.id} />;
}

export default function BookmarksPage() {
  return (
    <Suspense>
      <Bookmarks />
    </Suspense>
  );
}
