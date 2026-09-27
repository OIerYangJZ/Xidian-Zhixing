'use client';

import { useLanguage } from '@/hooks/useLanguage';
import { cn } from '@/lib/cn';
import type { GetPost } from '@/types/definitions';

const chip = 'inline-flex h-5 items-center rounded px-1.5 text-[11px] font-medium leading-none';

/** Section, pin, progress and review state: the parts of a post that are not its body. */
export function PostMeta({ post }: { post: GetPost }) {
  const { t } = useLanguage();
  const showSection = post.sectionName && post.sectionId !== 'general';
  if (
    !post.isPinned &&
    !showSection &&
    post.progress === 'ongoing' &&
    post.status === 'PUBLISHED' &&
    !post.isPrivate &&
    !post.editedAt
  )
    return null;

  return (
    <div className="mt-1 flex flex-wrap items-center gap-1.5">
      {post.isPinned && <span className={cn(chip, 'bg-primary/10 text-primary')}>{t('置顶', 'Pinned')}</span>}
      {showSection && <span className={cn(chip, 'bg-secondary text-muted-foreground')}>{post.sectionName}</span>}
      {post.progress === 'resolved' && (
        <span className={cn(chip, 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400')}>
          {t('已解决', 'Resolved')}
        </span>
      )}
      {post.progress === 'closed' && (
        <span className={cn(chip, 'bg-secondary text-muted-foreground')}>{t('已关闭', 'Closed')}</span>
      )}
      {post.status === 'PENDING_REVIEW' && (
        <span className={cn(chip, 'bg-amber-500/10 text-amber-600 dark:text-amber-400')}>
          {t('审核中，仅自己可见', 'In review · only you')}
        </span>
      )}
      {post.status === 'REMOVED' && (
        <span className={cn(chip, 'bg-destructive/10 text-destructive')}>{t('未通过审核', 'Rejected')}</span>
      )}
      {post.editedAt && <span className={cn(chip, 'bg-secondary text-muted-foreground')}>{t('已编辑', 'Edited')}</span>}
      {post.isPrivate && (
        <span className={cn(chip, 'bg-secondary text-muted-foreground')}>{t('仅自己可见', 'Only you')}</span>
      )}
    </div>
  );
}
