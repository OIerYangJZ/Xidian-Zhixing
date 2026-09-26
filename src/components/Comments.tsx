'use client';

import { useCallback, useMemo, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { GetComment } from '@/types/definitions';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getComments } from '@/lib/client_data_fetching/getComments';
import { useSession } from 'next-auth/react';
import { useShouldAnimate } from '@/hooks/useShouldAnimate';
import { useLanguage } from '@/hooks/useLanguage';
import { commentFramerVariants } from '@/lib/framerVariants';
import { CommentCreate } from './CommentCreate';
import { Comment } from './Comment';

export function Comments({ postId }: { postId: number }) {
  const { t } = useLanguage();
  const qc = useQueryClient();
  const [sort, setSort] = useState<'hot' | 'time'>('hot');
  const queryKey = useMemo(() => ['posts', postId, 'comments', sort], [postId, sort]);

  const { data: session } = useSession();
  const { shouldAnimate } = useShouldAnimate();

  const {
    data: comments,
    isPending,
    isError,
    error,
  } = useQuery<GetComment[], Error>({
    queryKey,
    queryFn: () => getComments({ postId, sort }),
    // staleTime: 60000 * 10,
  });

  const setRepliesVisibility = useCallback(
    ({ commentId, shown }: { commentId: number; shown: boolean }) => {
      qc.setQueryData<GetComment[]>(queryKey, (oldComments) => {
        if (!oldComments) return oldComments;
        // Make a shallow copy of `oldComments`
        const newComments = [...oldComments];

        // Find the index of the comment to update
        const index = newComments.findIndex((comment) => comment.id === commentId);

        const oldComment = newComments[index];

        newComments[index] = {
          ...oldComment,
          repliesShown: shown,
        };

        return newComments;
      });
    },
    [qc, queryKey],
  );

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
            {comments.length > 0 ? (
              comments?.map((comment) => (
                <motion.div
                  variants={commentFramerVariants}
                  initial={shouldAnimate ? 'start' : false}
                  animate="animate"
                  exit="exit"
                  key={`posts-${postId}-comments-${comment.id}`}>
                  <Comment
                    {...comment}
                    {...{
                      setRepliesVisibility,
                      queryKey,
                    }}
                    isOwnComment={session?.user?.id === comment.user.id}
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
