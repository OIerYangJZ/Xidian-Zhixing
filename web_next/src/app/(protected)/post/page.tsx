'use client';

import { Post } from '@/components/Post';
import { Suspense, useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { ArrowChevronBack } from '@/svg_components';
import { useQueryClient } from '@tanstack/react-query';
import { GetPost } from '@/types/definitions';
import { useLanguage } from '@/hooks/useLanguage';
import { useQueryParam } from '@/hooks/useQueryParam';
import { recordPostView } from '@/lib/backend/endpoints';

function PostDetail() {
  const postId = useQueryParam('id');
  const { t } = useLanguage();
  const qc = useQueryClient();
  const counted = useRef('');
  const [commentsShown, setCommentsShown] = useState(true);
  useEffect(() => {
    // Once per opened post: the view endpoint is rate limited, and repeated
    // excess signs the user out (see docs/backend-api-contract.md).
    if (!postId || counted.current === postId) return;
    counted.current = postId;
    recordPostView(postId)
      .then(({ viewCount }) =>
        qc.setQueryData<GetPost>(['posts', postId], (post) => (post ? { ...post, viewCount } : post)),
      )
      .catch(() => undefined);
  }, [postId, qc]);

  const toggleComments = useCallback(() => setCommentsShown((prev) => !prev), []);

  return (
    <div>
      <header className="sticky top-0 z-20 flex h-14 items-center gap-5 border-b border-border bg-background/90 px-4 backdrop-blur-md">
        <Link
          href="/feed"
          aria-label={t('返回首页', 'Back to home')}
          className="grid h-10 w-10 place-items-center rounded-full hover:bg-secondary">
          <ArrowChevronBack className="h-5 w-5 stroke-current" />
        </Link>
        <h1 className="text-lg font-bold">{t('帖子', 'Post')}</h1>
      </header>
      {postId ? (
        <Post id={postId} commentsShown={commentsShown} toggleComments={toggleComments} />
      ) : (
        <p className="px-4 py-6 text-sm text-muted-foreground">{t('这条动态已不存在。', 'This post is no longer available.')}</p>
      )}
    </div>
  );
}

export default function Page() {
  return (
    <Suspense>
      <PostDetail />
    </Suspense>
  );
}
