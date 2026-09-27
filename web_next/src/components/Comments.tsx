'use client';

import { useCallback, useMemo, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { GetComment } from '@/types/definitions';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { listComments } from '@/lib/backend/endpoints';
import { buildCommentThreads } from '@/lib/commentThreads';
import { useShouldAnimate } from '@/hooks/useShouldAnimate';
import { useLanguage } from '@/hooks/useLanguage';
import { commentFramerVariants } from '@/lib/framerVariants';
import { CommentCreate } from './CommentCreate';
import { Comment } from './Comment';

export function Comments({ postId }: { postId: string }) {
  const { t } = useLanguage();
  const qc = useQueryClient();
  const [sort, setSort] = useState<'hot' | 'time'>('hot');
  const queryKey = useMemo(() => ['posts', postId, 'comments', sort], [postId, sort]);
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(() => new Set());

  const { shouldAnimate } = useShouldAnimate();

  const {
    data: comments,
    isPending,
    isError,
    error,
  } = useQuery<GetComment[], Error>({
    queryKey,
    queryFn: () => listComments(postId, sort === 'hot' ? 'hot' : 'latest'),
    // staleTime: 60000 * 10,
  });

  const threads = useMemo(() => buildCommentThreads(comments ?? []), [comments]);
  const setRepliesVisibility = useCallback(({ commentId, shown }: { commentId: string; shown: boolean }) => {
    setExpanded((current) => {
      const next = new Set(current);
      if (shown) next.add(commentId);
      else next.delete(commentId);
      return next;
    });
  }, []);

  return (
    <div>
      <div className="flex flex-col pt-2">
        <div className="flex items-center justify-between border-y border-border py-2">
          <span className="text-sm font-semibold">{t('评论排序', 'Sort replies')}</span>
          <select
            aria-label={t('评论排序', 'Sort replies')}
            value={sort}
            onChange={(event) => setSort(event.target.value as 'hot' | 'time')}
            className="bg-transparent px-2 py-1 text-sm font-medium text-muted-foreground outline-none focus-visible:ring-2 focus-visible:ring-primary">
            <option value="hot">{t('热度', 'Popularity')}</option>
            <option value="time">{t('时间', 'Time')}</option>
          </select>
        </div>
        {isPending ? (
          <p className="py-2 text-sm text-muted-foreground">{t('正在加载评论…', 'Loading replies…')}</p>
        ) : isError ? (
          <p className="py-2 text-muted-foreground">{error.message}</p>
        ) : (
          <AnimatePresence>
            {threads.length > 0 ? (
              threads.map(({ root: comment, replies }) => (
                <motion.div
                  variants={commentFramerVariants}
                  initial={shouldAnimate ? 'start' : false}
                  animate="animate"
                  exit="exit"
                  key={`posts-${postId}-comments-${comment.id}`}>
                  <Comment
                    {...comment}
                    replies={replies}
                    repliesShown={expanded.has(comment.id)}
                    setRepliesVisibility={setRepliesVisibility}
                  />
                </motion.div>
              ))
            ) : (
              <p className="py-2 text-sm text-muted-foreground">
                {t('来留下第一条评论吧。', 'Be the first to reply.')}
              </p>
            )}
          </AnimatePresence>
        )}
      </div>
      <CommentCreate postId={postId} />
    </div>
  );
}
