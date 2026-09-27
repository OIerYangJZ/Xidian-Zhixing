/* eslint-disable import/no-duplicates */
import { formatDistanceToNowStrict } from 'date-fns';
import { enUS, zhCN } from 'date-fns/locale';

import { cn } from '@/lib/cn';
import { useEffect, useRef } from 'react';
import Link from 'next/link';
import { profileHref } from '@/lib/profileHref';
import { useLanguage } from '@/hooks/useLanguage';
import { HighlightedMentionsAndHashTags } from './HighlightedMentionsAndHashTags';

export function CommentContent({
  name,
  username,
  content,
  createdAt,
  shouldHighlight,
  isPostAuthor = false,
  isPending = false,
  replyToName = null,
}: {
  name: string | null;
  username: string | null;
  content: string;
  createdAt: string | Date;
  shouldHighlight?: boolean;
  /** 洞主: the post's own author */
  isPostAuthor?: boolean;
  isPending?: boolean;
  /** Who this reply answers, when that is not the thread's first comment. */
  replyToName?: string | null;
}) {
  const { language, t } = useLanguage();
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!shouldHighlight) return;
    if (ref.current) ref.current.scrollIntoView({ behavior: 'smooth' });
  }, [shouldHighlight]);

  return (
    <div ref={ref}>
      <div className="flex min-w-0 flex-wrap items-center gap-x-1.5 text-sm">
        <h3 className="truncate font-semibold">
          {profileHref(username) ? (
            <Link href={profileHref(username)!} className="link text-foreground">
              {name}
            </Link>
          ) : (
            <span className="text-foreground">{name}</span>
          )}
        </h3>
        {isPostAuthor && (
          <span className="rounded bg-primary/10 px-1 text-[11px] font-medium leading-4 text-primary">
            {t('洞主', 'OP')}
          </span>
        )}
        <span className="text-muted-foreground" aria-hidden="true">
          ·
        </span>
        <span className="text-xs text-muted-foreground">
          {formatDistanceToNowStrict(new Date(createdAt), { addSuffix: true, locale: language === 'zh' ? zhCN : enUS })}
        </span>
        {isPending && <span className="text-xs text-amber-600 dark:text-amber-400">{t('审核中', 'In review')}</span>}
      </div>
      <div className={cn('mt-1 rounded-lg', shouldHighlight && 'ring-2 ring-primary ring-offset-2')}>
        <p className="whitespace-pre-wrap break-words text-[15px] leading-6 text-foreground">
          {replyToName && (
            <span className="mr-1 text-muted-foreground">
              {t('回复', 'Replying to')} <span className="font-medium text-foreground">@{replyToName}</span>:
            </span>
          )}
          <HighlightedMentionsAndHashTags text={content} shouldAddLinks />
        </p>
      </div>
    </div>
  );
}
