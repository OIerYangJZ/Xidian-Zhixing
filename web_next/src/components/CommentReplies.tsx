'use client';

import { AnimatePresence, motion } from 'framer-motion';
import { useShouldAnimate } from '@/hooks/useShouldAnimate';
import { commentFramerVariants } from '@/lib/framerVariants';
import type { CommentReplyItem } from '@/lib/commentThreads';
import { CommentReply } from './CommentReply';

/** Every reply under one root comment, oldest first (see buildCommentThreads). */
export function CommentReplies({ postId, replies }: { postId: string; replies: CommentReplyItem[] }) {
  const { shouldAnimate } = useShouldAnimate();

  return (
    <div>
      <AnimatePresence>
        {replies.map((reply) => (
          <motion.div
            variants={commentFramerVariants}
            initial={shouldAnimate ? 'start' : false}
            animate="animate"
            exit="exit"
            key={`posts-${postId}-replies-${reply.id}`}>
            <CommentReply {...reply} />
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
