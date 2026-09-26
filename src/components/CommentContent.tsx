/* eslint-disable import/no-duplicates */
import { formatDistanceToNowStrict } from 'date-fns';
import { enUS, zhCN } from 'date-fns/locale';

import { cn } from '@/lib/cn';
import { useEffect, useRef } from 'react';
import Link from 'next/link';
import { useLanguage } from '@/hooks/useLanguage';
import { HighlightedMentionsAndHashTags } from './HighlightedMentionsAndHashTags';

export function CommentContent({
  name,
  username,
  content,
  createdAt,
  shouldHighlight,
}: {
  name: string | null;
  username: string | null;
  content: string;
  createdAt: string | Date;
  shouldHighlight?: boolean;
}) {
  const { language } = useLanguage();
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!shouldHighlight) return;
    if (ref.current) ref.current.scrollIntoView({ behavior: 'smooth' });
  }, [shouldHighlight]);

  return (
    <div ref={ref}>
      <div className="flex min-w-0 flex-wrap items-center gap-x-1.5 text-sm">
        <h3 className="truncate font-semibold">
          <Link href={`/${username}`} className="link text-foreground">
            {name}
          </Link>
        </h3>
        <span className="truncate text-muted-foreground">@{username}</span>
        <span className="text-muted-foreground" aria-hidden="true">
          ·
        </span>
        <span className="text-xs text-muted-foreground">
          {formatDistanceToNowStrict(new Date(createdAt), { addSuffix: true, locale: language === 'zh' ? zhCN : enUS })}
        </span>
      </div>
      <div className={cn('mt-1 rounded-lg', shouldHighlight && 'ring-2 ring-primary ring-offset-2')}>
        <p className="whitespace-pre-wrap break-words text-[15px] leading-6 text-foreground">
          <HighlightedMentionsAndHashTags text={content} shouldAddLinks />
        </p>
      </div>
    </div>
  );
}
