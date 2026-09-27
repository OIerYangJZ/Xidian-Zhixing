'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { useLanguage } from '@/hooks/useLanguage';
import { listHotTopics } from '@/lib/backend/endpoints';
import { postHref } from '@/lib/profileHref';

const SHOWN = 5;

/**
 * Right-rail module.  The backend has no follow recommendations, so this slot
 * shows today's hot list (热榜) instead.
 */
export function SuggestedFollows() {
  const { t } = useLanguage();
  const { data: topics = [] } = useQuery({
    queryKey: ['hot-topics'],
    queryFn: listHotTopics,
    staleTime: 60000 * 5,
  });

  if (!topics.length) return null;
  return (
    <section className="quiet-surface overflow-hidden rounded-lg">
      <h2 className="px-4 py-3 text-base font-semibold">{t('今日热榜', 'Trending today')}</h2>
      {topics.slice(0, SHOWN).map((topic) => (
        <Link
          key={topic.id}
          href={postHref(topic.postId)}
          className="flex items-start gap-3 border-t border-border/70 px-4 py-3 hover:bg-secondary/40">
          <span className="w-4 shrink-0 text-sm font-semibold text-primary">{topic.rank}</span>
          <span className="min-w-0">
            <span className="line-clamp-2 text-sm font-medium">{topic.title}</span>
            {topic.sectionName && (
              <span className="mt-0.5 block text-xs text-muted-foreground">{topic.sectionName}</span>
            )}
          </span>
        </Link>
      ))}
    </section>
  );
}
