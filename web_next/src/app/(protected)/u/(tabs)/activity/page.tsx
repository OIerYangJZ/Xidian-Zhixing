'use client';

import { Suspense, useEffect, useRef } from 'react';
import Link from 'next/link';
import { useInfiniteQuery } from '@tanstack/react-query';
/* eslint-disable import/no-duplicates */
import { formatDistanceToNowStrict } from 'date-fns';
import { enUS, zhCN } from 'date-fns/locale';
/* eslint-enable import/no-duplicates */
import useOnScreen from '@/hooks/useOnScreen';
import { useLanguage } from '@/hooks/useLanguage';
import { useSession } from '@/lib/backend/session';
import { listMyActivity } from '@/lib/backend/endpoints';
import type { ApiActivity } from '@/lib/backend/types';
import { postHref, profileHref } from '@/lib/profileHref';
import { GenericLoading } from '@/components/GenericLoading';
import { SomethingWentWrong } from '@/components/SometingWentWrong';
import { AllCaughtUp } from '@/components/AllCaughtUp';
import { useProfileId } from '../../useProfileId';

const PAGE_SIZE = 20;

function describe(item: ApiActivity, t: (zh: string, en: string) => string): string {
  switch (item.type) {
    case 'post':
      return item.isAnonymous ? t('匿名发布了帖子', 'posted anonymously') : t('发布了帖子', 'posted');
    case 'comment':
      return t('评论了', 'commented on');
    case 'like_post':
      return t('赞了帖子', 'liked');
    case 'like_comment':
      return t('赞了评论', 'liked a comment on');
    case 'favorite':
      return t('收藏了', 'saved');
    case 'repost':
      return t('转发了', 'reposted');
    default:
      return t('关注了', 'followed');
  }
}

function ActivityRow({ item }: { item: ApiActivity }) {
  const { t, language } = useLanguage();
  const when = item.createdAt
    ? formatDistanceToNowStrict(new Date(item.createdAt), { addSuffix: true, locale: language === 'zh' ? zhCN : enUS })
    : '';
  const href =
    item.type === 'follow' ? profileHref(item.user?.userId) : item.post ? postHref(item.post.id, item.commentId) : null;
  const target = item.type === 'follow' ? item.user?.nickname : item.post?.title;

  const body = (
    <>
      <p className="text-sm leading-5">
        <span className="text-muted-foreground">{t('你', 'You')}</span> {describe(item, t)}{' '}
        <span className="font-semibold">{target || t('（无标题）', '(untitled)')}</span>
      </p>
      {item.content && <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">“{item.content}”</p>}
      <p className="mt-1 text-xs text-muted-foreground">{when}</p>
    </>
  );
  return (
    <li className="feed-separator border-b">
      {href ? (
        <Link href={href} className="block px-1 py-3 hover:bg-foreground/[0.025]">
          {body}
        </Link>
      ) : (
        <div className="px-1 py-3">{body}</div>
      )}
    </li>
  );
}

function ActivityList() {
  const { t } = useLanguage();
  const profileId = useProfileId();
  const { data: session } = useSession();
  const isOwn = !!session && session.user.id === profileId;
  const bottomRef = useRef<HTMLDivElement>(null);
  const isBottomOnScreen = useOnScreen(bottomRef);
  const { data, isPending, isError, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
    queryKey: ['users', 'me', 'activity'],
    initialPageParam: 1,
    enabled: isOwn,
    queryFn: ({ pageParam }) => listMyActivity(pageParam, PAGE_SIZE),
    getNextPageParam: (lastPage) => (lastPage.hasMore ? lastPage.page + 1 : undefined),
  });

  useEffect(() => {
    if (isBottomOnScreen && hasNextPage && !isFetchingNextPage) fetchNextPage();
  }, [isBottomOnScreen, hasNextPage, isFetchingNextPage, fetchNextPage]);

  // Private history: the tab only exists on one's own profile.
  if (!isOwn) return null;
  if (isPending) return <GenericLoading>{t('正在加载互动', 'Loading activity')}</GenericLoading>;
  if (isError) return <SomethingWentWrong />;

  const items = data.pages.flatMap((page) => page.items);
  return (
    <div>
      {items.length === 0 ? (
        <p className="py-6 text-sm text-muted-foreground">{t('还没有互动记录。', 'No activity yet.')}</p>
      ) : (
        <ul>
          {items.map((item) => (
            <ActivityRow key={item.id} item={item} />
          ))}
        </ul>
      )}
      <div ref={bottomRef} className="h-6" />
      {isFetchingNextPage && <GenericLoading>{t('正在加载更多', 'Loading more')}</GenericLoading>}
      {!hasNextPage && items.length > 0 && <AllCaughtUp />}
    </div>
  );
}

export default function Page() {
  return (
    <Suspense>
      <ActivityList />
    </Suspense>
  );
}
