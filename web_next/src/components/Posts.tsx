'use client';

import { InfiniteData, QueryKey, useInfiniteQuery, useQueryClient } from '@tanstack/react-query';
import type { PostIds, PostsPage } from '@/types/definitions';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import useOnScreen from '@/hooks/useOnScreen';
import { AnimatePresence, motion } from 'framer-motion';
import { POSTS_PER_PAGE } from '@/constants';
import { listFavoritePosts, listPosts, listTimeline, type PostSort, type TimelineEntry } from '@/lib/backend/endpoints';
import { useShouldAnimate } from '@/hooks/useShouldAnimate';
import { useLanguage } from '@/hooks/useLanguage';
import { deductLowerMultiple } from '@/lib/deductLowerMultiple';
import SvgForwardArrow from '@/svg_components/ForwardArrow';
import { postFramerVariants } from '@/lib/framerVariants';
import { SomethingWentWrong } from './SometingWentWrong';
import { ButtonNaked } from './ui/ButtonNaked';
import { AllCaughtUp } from './AllCaughtUp';
import { Post } from './Post';
import { GenericLoading } from './GenericLoading';
import { PostSkeleton } from './PostSkeleton';

// If the `type` is 'profile' or 'bookmarks', the `userId` property is required
// If the `type` is 'hashtag', the `hashtag` property is required
type PostsProps =
  | {
      type: 'hashtag';
      userId?: undefined;
      hashtag: string;
      keyword?: undefined;
      sort?: PostSort;
      sectionId?: undefined;
    }
  | {
      type: 'search';
      userId?: undefined;
      hashtag?: undefined;
      /** Matched against title, content and tags. */
      keyword: string;
      sort?: PostSort;
      sectionId?: undefined;
    }
  | {
      type: 'feed';
      userId?: string;
      hashtag?: undefined;
      keyword?: undefined;
      sort?: PostSort;
      /** Restrict the feed to one section (板块). */
      sectionId?: string;
    }
  | {
      type: 'profile' | 'bookmarks';
      userId: string;
      hashtag?: undefined;
      keyword?: undefined;
      sort?: undefined;
      sectionId?: undefined;
    };

type PageParam = number;

type PageEntries = { entries: TimelineEntry[]; hasMore: boolean };

async function fetchPage(
  { type, userId, hashtag, keyword, sort, sectionId }: PostsProps,
  page: PageParam,
): Promise<PageEntries> {
  // A profile shows what the user wrote and what they reposted.
  if (type === 'profile') return listTimeline(userId, page, POSTS_PER_PAGE);
  const { posts, hasMore } =
    type === 'bookmarks'
      ? await listFavoritePosts()
      : await listPosts({
          page,
          limit: POSTS_PER_PAGE,
          sort: sort || 'latest',
          ...(type === 'hashtag' && { tag: hashtag }),
          ...(type === 'search' && { keyword }),
          ...(type === 'feed' && sectionId && { sectionId }),
        });
  return { entries: posts.map((post) => ({ post, repostedBy: null, eventKey: '' })), hasMore };
}

export function Posts(props: PostsProps) {
  const { type, hashtag, keyword, userId, sort, sectionId } = props;
  const { t } = useLanguage();
  const qc = useQueryClient();
  // Need to memoize `queryKey`, so when used in a dependency array, it won't trigger the `useEffect`/`useCallback`
  const queryKey = useMemo(
    () =>
      type === 'hashtag' || type === 'search'
        ? ['posts', { hashtag, keyword, sort }]
        : type === 'feed'
        ? ['posts', 'feed', { sort: sort || 'latest', sectionId: sectionId || '' }]
        : ['users', userId, 'posts', { type }],
    [type, userId, hashtag, keyword, sort, sectionId],
  );
  const topElRef = useRef<HTMLDivElement>(null);
  const bottomElRef = useRef<HTMLDivElement>(null);
  const isBottomOnScreen = useOnScreen(bottomElRef);
  // `shouldAnimate` is `false` when the browser's back button is pressed
  // `true` when the page is pushed
  const { shouldAnimate } = useShouldAnimate();
  // Posts published since the first page was loaded (feed polling only).
  const [numberOfNewPostsLoaded, setNumberOfNewPostsLoaded] = useState(0);
  const { data, isPending, isError, fetchNextPage, hasNextPage, isFetchingNextPage, refetch } = useInfiniteQuery<
    PostsPage,
    Error,
    InfiniteData<PostsPage>,
    QueryKey,
    PageParam
  >({
    queryKey,
    initialPageParam: 1,
    queryFn: async ({ pageParam }): Promise<PostsPage> => {
      const { entries, hasMore } = await fetchPage(props, pageParam);
      const postIds: PostIds = entries.map(({ post, repostedBy, eventKey }) => {
        // Set query data for each `post`, these queries will be used by the <Post> component
        qc.setQueryData(['posts', post.id], post);

        // If the `post` already exists in `data`, make sure to use its current `commentsShown`
        // value to prevent the post's comment section from closing if it is already shown
        const currentPostId = data?.pages
          .flatMap((loaded) => loaded.items)
          .find(({ id, feedEventKey }) => id === post.id && (feedEventKey || '') === eventKey);
        return {
          id: post.id,
          commentsShown: currentPostId?.commentsShown || false,
          ...(eventKey && { feedEventKey: eventKey }),
          ...(repostedBy && { repostedBy: { name: repostedBy.nickname, username: repostedBy.userId } }),
        };
      });
      return { items: postIds, hasMore };
    },
    getNextPageParam: (lastPage, _pages, lastPageParam) => (lastPage.hasMore ? lastPageParam + 1 : undefined),
    refetchOnWindowFocus: false,
    staleTime: Infinity,
    retry: false,
  });

  useEffect(() => {
    // Refresh pushed-to pages without clearing the cached timeline, so returning
    // to the feed keeps its content visible while the latest posts load.
    if (shouldAnimate) {
      // The query uses an infinite stale time, so explicitly mark it stale on a push.
      qc.invalidateQueries({ queryKey, exact: true });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    // The backend pages by number, not by cursor, so new posts are detected by
    // peeking at page one and counting ids the timeline has not seen yet.
    if (type !== 'feed') return undefined;
    const interval = setInterval(async () => {
      try {
        const { entries } = await fetchPage(props, 1);
        const seen = new Set(
          qc
            .getQueryData<InfiniteData<PostsPage>>(queryKey)
            ?.pages.flatMap((page) => page.items)
            .map(({ id }) => id),
        );
        setNumberOfNewPostsLoaded(entries.filter(({ post }) => !seen.has(post.id)).length);
      } catch {
        // Polling is best-effort.
      }
    }, 30000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [type, queryKey]);

  useEffect(() => {
    if (isBottomOnScreen && hasNextPage) fetchNextPage();
  }, [isBottomOnScreen, hasNextPage, fetchNextPage]);

  const viewNewlyLoadedPosts = useCallback(() => {
    topElRef.current?.scrollIntoView({ behavior: 'smooth' });
    setNumberOfNewPostsLoaded(0);
    refetch();
  }, [refetch]);

  const toggleComments = useCallback(
    async (postId: string, feedEventKey?: string) => {
      // In place, page by page: pages are numbered on the backend and may be
      // short, so re-chunking would move posts between pages.
      qc.setQueryData<InfiniteData<PostsPage>>(queryKey, (oldData) =>
        oldData
          ? {
              ...oldData,
              pages: oldData.pages.map((page) => ({
                ...page,
                items: page.items.map((post) =>
                  post.id === postId && (!feedEventKey || post.feedEventKey === feedEventKey)
                    ? { ...post, commentsShown: !post.commentsShown }
                    : post,
                ),
              })),
            }
          : oldData,
      );
    },
    [qc, queryKey],
  );

  const newPostsLoadedButtonVariants = useMemo(
    () => ({
      hidden: { height: 0 },
      visible: { height: 'auto' },
    }),
    [],
  );
  const postTransition = useCallback(
    (i: number) => ({
      delay: deductLowerMultiple(i, POSTS_PER_PAGE) * 0.115,
    }),
    [],
  );
  const bottomLoaderStyle = useMemo(() => ({ display: data ? 'block' : 'none' }), [data]);
  // The backend pages by offset: a post published after page one loaded
  // shifts everything down, so page two starts with page one's last post.
  // Show each entry once, where it first appeared.
  const pages = useMemo(() => {
    const seen = new Set<string>();
    return (data?.pages ?? []).map((page) =>
      page.items.filter((post) => {
        const key = post.feedEventKey || post.id;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      }),
    );
  }, [data]);

  return (
    <>
      <div ref={topElRef} />
      <div className="flex flex-col">
        <AnimatePresence>
          {numberOfNewPostsLoaded !== 0 && (
            <motion.div
              // eslint-disable-next-line @typescript-eslint/no-use-before-define
              variants={newPostsLoadedButtonVariants}
              initial="hidden"
              animate="visible"
              exit="hidden"
              className="sticky top-5 z-10 mx-auto overflow-hidden">
              <ButtonNaked
                onPress={viewNewlyLoadedPosts}
                className="mt-4 inline-flex cursor-pointer select-none items-center gap-3 rounded-full bg-primary px-4 py-2 hover:bg-primary-accent">
                <div className="-rotate-90 rounded-full border-2 border-border bg-muted/70 p-[6px]">
                  <SvgForwardArrow className="h-5 w-5" />
                </div>
                <p className="text-primary-foreground">
                  {t('已有', '')} <b>{numberOfNewPostsLoaded}</b> {t('条新动态', 'new posts')}
                </p>
              </ButtonNaked>
            </motion.div>
          )}
        </AnimatePresence>
        {isPending ? (
          <div>
            <PostSkeleton />
            <PostSkeleton />
            <PostSkeleton />
          </div>
        ) : (
          <AnimatePresence>
            {pages.map((page) =>
              page.map((post, i) => (
                <motion.div
                  variants={postFramerVariants}
                  initial={shouldAnimate ? 'start' : false}
                  animate="animate"
                  exit="exit"
                  transition={postTransition(i)}
                  key={post.feedEventKey || post.id}>
                  <Post
                    id={post.id}
                    feedEventKey={post.feedEventKey}
                    repostedBy={post.repostedBy}
                    commentsShown={post.commentsShown}
                    toggleComments={toggleComments}
                  />
                </motion.div>
              )),
            )}
          </AnimatePresence>
        )}
      </div>

      <div
        className="min-h-[16px]"
        ref={bottomElRef}
        /**
         * The first page will be initially loaded by React Query
         * so the bottom loader has to be hidden first
         */
        style={bottomLoaderStyle}>
        {isFetchingNextPage && <GenericLoading>{t('正在加载更多动态…', 'Loading more posts…')}</GenericLoading>}
      </div>
      {isError && <SomethingWentWrong />}
      {!isPending && !isFetchingNextPage && !hasNextPage && <AllCaughtUp />}
    </>
  );
}
