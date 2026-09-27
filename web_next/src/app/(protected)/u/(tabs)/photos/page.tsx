'use client';

import { Suspense } from 'react';
import { useQuery } from '@tanstack/react-query';
import { listPosts } from '@/lib/backend/endpoints';
import type { GetVisualMedia } from '@/types/definitions';
import { Gallery } from './Gallery';
import { useProfileId } from '../../useProfileId';

/** The newest images a user posted publicly under their own name. */
const PHOTO_POST_LIMIT = 60;
const NO_MEDIA: GetVisualMedia[] = [];

function Photos() {
  const profileId = useProfileId();
  const { data: visualMedia = NO_MEDIA } = useQuery({
    queryKey: ['users', profileId, 'photos'],
    enabled: !!profileId,
    queryFn: async (): Promise<GetVisualMedia[]> => {
      // authorId already leaves out anonymous posts unless they are the viewer's own.
      const { posts } = await listPosts({ page: 1, limit: PHOTO_POST_LIMIT, authorId: profileId, hasImage: true });
      return posts.filter((post) => post.displayIdentity !== 'ANONYMOUS').flatMap((post) => post.visualMedia);
    },
  });
  return <Gallery visualMedia={visualMedia} />;
}

export default function Page() {
  return (
    <Suspense>
      <Photos />
    </Suspense>
  );
}
