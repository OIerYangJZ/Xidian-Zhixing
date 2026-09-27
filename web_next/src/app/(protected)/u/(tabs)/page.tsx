'use client';

import { Suspense } from 'react';
import { Posts } from '@/components/Posts';
import { CreatePostModalLauncher } from '@/components/CreatePostModalLauncher';
import { useSession } from '@/lib/backend/session';
import { useProfileId } from '../useProfileId';

function ProfilePosts() {
  const profileId = useProfileId();
  const { data: session } = useSession();
  if (!profileId) return null;

  return (
    <div>
      {session?.user.id === profileId && (
        <div className="mt-4">
          <CreatePostModalLauncher />
        </div>
      )}
      <Posts type="profile" userId={profileId} />
    </div>
  );
}

export default function Page() {
  return (
    <Suspense>
      <ProfilePosts />
    </Suspense>
  );
}
