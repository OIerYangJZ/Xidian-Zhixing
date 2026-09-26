'use client';

import { Post } from '@/components/Post';
import { useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { ArrowChevronBack } from '@/svg_components';
import { useQueryClient } from '@tanstack/react-query';
import { GetPost } from '@/types/definitions';

export default function Page({ params }: { params: { postId: string } }) {
  const postId = parseInt(params.postId, 10);
  const qc = useQueryClient();
  const counted = useRef(false);
  const [commentsShown, setCommentsShown] = useState(true);
  useEffect(() => {
    if (counted.current) return;
    counted.current = true;
    fetch(`/api/posts/${postId}`, { method: 'POST' })
      .then((response) => response.json() as Promise<{ viewCount: number }>)
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
          aria-label="返回首页"
          className="grid h-10 w-10 place-items-center rounded-full hover:bg-secondary">
          <ArrowChevronBack className="h-5 w-5 stroke-current" />
        </Link>
        <h1 className="text-lg font-bold">帖子</h1>
      </header>
      <Post id={postId} commentsShown={commentsShown} toggleComments={toggleComments} />
    </div>
  );
}
