'use client';

import { Suspense } from 'react';
import { Posts } from '@/components/Posts';
import { PageHeader } from '@/components/ui/PageHeader';
import { useQueryParam } from '@/hooks/useQueryParam';

function TagPosts() {
  const hashtag = useQueryParam('name');
  return (
    <div>
      <PageHeader title={`#${hashtag}`} sticky />
      {hashtag && <Posts type="hashtag" hashtag={hashtag} />}
    </div>
  );
}

export default function Page() {
  return (
    <Suspense>
      <TagPosts />
    </Suspense>
  );
}
