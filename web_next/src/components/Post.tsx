'use client';

import { memo, useCallback, useMemo } from 'react';
import type { SVGProps } from 'react';
import { cn } from '@/lib/cn';
import { useLanguage } from '@/hooks/useLanguage';
/* eslint-disable import/no-duplicates */
import { formatDistanceToNowStrict } from 'date-fns';
import { zhCN, enUS } from 'date-fns/locale';

import SvgComment from '@/svg_components/Comment';
import { AnimatePresence, motion } from 'framer-motion';
import { GetPost, PostId } from '@/types/definitions';
import { postHref, profileHref } from '@/lib/profileHref';
import { isEqual } from 'lodash';
import SvgHeart from '@/svg_components/Heart';
import SvgBookmark from '@/svg_components/Bookmark';
import { useQuery } from '@tanstack/react-query';
import { usePostLikesMutations } from '@/hooks/mutations/usePostLikesMutations';
import { usePostBookmarkMutations } from '@/hooks/mutations/usePostBookmarkMutations';
import { usePostRepostMutation } from '@/hooks/mutations/usePostRepostMutation';
import { useToast } from '@/hooks/useToast';
import { getPost } from '@/lib/backend/endpoints';
import { useReportDialog } from '@/hooks/useReportDialog';
import Link from 'next/link';
import { Avatar } from '@/components/ui/Avatar';
import { PostMeta } from './PostMeta';
import { RepostIcon } from './icons/RepostIcon';
import { ToggleStepper } from './ui/ToggleStepper';
import { Comments } from './Comments';
import { PostVisualMediaContainer } from './PostVisualMediaContainer';
import ProfileBlock from './ProfileBlock';
import { ProfilePhoto } from './ui/ProfilePhoto';
import { HighlightedMentionsAndHashTags } from './HighlightedMentionsAndHashTags';
import { PostOptions } from './PostOptions';

function formatCount(count: number) {
  return count >= 10000 ? `${(count / 10000).toFixed(1).replace(/\.0$/, '')}万` : count.toLocaleString();
}

function AnalyticsIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <path d="M3 20V11m6 9V4m6 16v-7m6 7V8" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}

function ShareIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <path
        d="M12 16V3m0 0L7 8m5-5 5 5M5 13v7h14v-7"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export const Post = memo(
  ({
    id: postId,
    commentsShown,
    feedEventKey,
    repostedBy,
    toggleComments,
  }: PostId & {
    toggleComments: (postId: string, feedEventKey?: string) => void;
  }) => {
    const { t, language } = useLanguage();
    const { showToast } = useToast();
    const { openReport } = useReportDialog();
    const { likeMutation, unLikeMutation } = usePostLikesMutations({ postId });
    const { bookmarkMutation, removeBookmarkMutation } = usePostBookmarkMutations({ postId });
    const repostMutation = usePostRepostMutation({ postId });
    const { data, isPending, isError } = useQuery<GetPost>({
      queryKey: ['posts', postId],
      queryFn: () => getPost(postId),
      staleTime: 60000 * 10,
    });

    const likePost = useCallback(() => likeMutation.mutate(), [likeMutation]);
    const unLikePost = useCallback(() => unLikeMutation.mutate(), [unLikeMutation]);
    const handleLikeToggle = useCallback(
      (isSelected: boolean) => {
        if (isSelected) {
          likePost();
        } else {
          unLikePost();
        }
      },
      [likePost, unLikePost],
    );
    const handleCommentsToggle = useCallback(() => {
      toggleComments(postId, feedEventKey);
    }, [feedEventKey, postId, toggleComments]);
    const sharePost = async () => {
      const url = `${window.location.origin}/p/${postId}`;
      try {
        if (navigator.share) {
          await navigator.share({ url });
          return;
        }
        await navigator.clipboard.writeText(url);
        showToast({
          title: t('链接已复制', 'Link copied'),
          message: t('可以把帖子链接分享给同学。', 'You can share the post link with classmates.'),
          type: 'success',
        });
      } catch (error) {
        if (error instanceof DOMException && error.name === 'AbortError') return;
        showToast({
          title: t('分享失败', 'Could not share'),
          message: t('请稍后重试。', 'Please try again.'),
          type: 'error',
        });
      }
    };
    const reportPost = () => openReport({ targetType: 'post', targetId: postId });
    const variants = useMemo(
      () => ({
        animate: {
          height: 'auto',
          overflow: 'visible',
        },
        exit: {
          height: 0,
          overflow: 'hidden',
        },
      }),
      [],
    );

    if (isPending)
      return <p className="px-4 py-6 text-sm text-muted-foreground">{t('正在加载动态…', 'Loading post…')}</p>;
    if (isError)
      return (
        <p className="px-4 py-6 text-sm text-muted-foreground">{t('动态加载失败。', 'Could not load this post.')}</p>
      );
    if (!data)
      return (
        <p className="px-4 py-6 text-sm text-muted-foreground">
          {t('这条动态已不存在。', 'This post is no longer available.')}
        </p>
      );

    // eslint-disable-next-line @typescript-eslint/naming-convention
    const {
      title,
      content,
      createdAt,
      user: author,
      authorAlias,
      authorAvatarUrl,
      publishedAsClub,
      displayIdentity,
      visualMedia,
      isLiked,
      isBookmarked,
      isReposted,
      viewCount,
      _count: postCounts,
    } = data;
    const { isOwnPost } = data;
    const numberOfLikes = postCounts.postLikes;
    const postTime = formatDistanceToNowStrict(new Date(createdAt), {
      addSuffix: true,
      locale: language === 'zh' ? zhCN : enUS,
    });

    return (
      // The replies control below provides keyboard access; clicking other card space is a pointer shortcut.
      // eslint-disable-next-line jsx-a11y/click-events-have-key-events, jsx-a11y/no-noninteractive-element-interactions
      <article
        className="feed-separator cursor-pointer border-b px-[12px] py-0 transition-colors hover:bg-foreground/[0.012] sm:px-[16px]"
        onClick={(event) => {
          const { target } = event;
          if (
            target instanceof Element &&
            target.closest(
              'a, button, input, textarea, select, [role="button"], [role="checkbox"], [data-post-interactive]',
            )
          ) {
            return;
          }
          handleCommentsToggle();
        }}>
        {repostedBy && (
          <div className="mb-1 flex items-center gap-2 pl-[60px] pt-2 text-xs text-muted-foreground">
            <RepostIcon className="h-3.5 w-3.5" aria-hidden="true" />
            {repostedBy.username ? (
              <Link href={profileHref(repostedBy.username)!} className="font-medium hover:underline">
                {repostedBy.name}
              </Link>
            ) : (
              <span className="font-medium">{repostedBy.name}</span>
            )}
            <span>{t('转发了', 'reposted')}</span>
          </div>
        )}
        <div className="relative pl-[60px]">
          <div className="absolute left-0 top-0 h-[48px] w-[48px]">
            {displayIdentity === 'ANONYMOUS' ? (
              <Avatar name={authorAlias || t('匿名同学', 'Anonymous')} anonymous />
            ) : displayIdentity === 'CLUB' && publishedAsClub ? (
              <Avatar name={publishedAsClub.name} photoUrl={publishedAsClub.avatar} />
            ) : author ? (
              <ProfilePhoto photoUrl={author.profilePhoto || ''} username={author.username} name={author.name} />
            ) : (
              // No profile link (one's own private post), but still a name.
              <Avatar name={authorAlias} photoUrl={authorAvatarUrl} />
            )}
          </div>
          <div className="relative pr-10">
            <div className="min-w-0">
              {displayIdentity === 'ANONYMOUS' ? (
                <div className="flex flex-wrap items-center gap-x-2">
                  <div className="text-sm font-semibold text-foreground">
                    {authorAlias || t('匿名同学', 'Anonymous student')}
                  </div>
                  <span className="text-sm text-muted-foreground">· {postTime}</span>
                </div>
              ) : displayIdentity === 'CLUB' && publishedAsClub ? (
                <div className="flex flex-wrap items-center gap-x-2">
                  <div className="text-sm font-semibold text-foreground">{publishedAsClub.name}</div>
                  <span className="text-sm text-muted-foreground">
                    {t('社团', 'Club')} · {postTime}
                  </span>
                </div>
              ) : author ? (
                <ProfileBlock
                  name={author.name}
                  username={author.username}
                  time={postTime}
                  photoUrl={author.profilePhoto || ''}
                  hideAvatar
                />
              ) : (
                <div className="flex flex-wrap items-center gap-x-2">
                  <div className="text-sm font-semibold text-foreground">{authorAlias}</div>
                  <span className="text-sm text-muted-foreground">· {postTime}</span>
                </div>
              )}
            </div>
            <div className="absolute right-0 top-0">{isOwnPost && <PostOptions post={data} />}</div>
          </div>
          <PostMeta post={data} />
          {title && <h2 className="mt-1 break-words text-[15px] font-semibold leading-6 text-foreground">{title}</h2>}
          {content && (
            <p className="mb-1.5 mt-1 whitespace-pre-wrap break-words text-sm leading-5 text-foreground">
              <HighlightedMentionsAndHashTags text={content} shouldAddLinks mentions={data.mentions} />
            </p>
          )}
          {visualMedia.length > 0 && (
            <div
              data-post-interactive
              className="mb-1 mt-1 overflow-hidden rounded-xl border border-border bg-secondary/30">
              <PostVisualMediaContainer visualMedia={visualMedia} />
            </div>
          )}
          <div data-post-interactive className="flex items-center justify-between text-muted-foreground">
            <ToggleStepper
              isSelected={commentsShown || false}
              aria-label={commentsShown ? t('隐藏评论', 'Hide replies') : t('显示评论', 'Show replies')}
              onChange={handleCommentsToggle}
              Icon={SvgComment}
              quantity={postCounts.comments}
              color="accent"
              compact
            />
            <ToggleStepper
              isSelected={isReposted}
              aria-label={isReposted ? t('取消转发', 'Undo repost') : t('转发', 'Repost')}
              isDisabled={repostMutation.isPending || data.isPrivate || (isOwnPost && displayIdentity === 'ANONYMOUS')}
              onChange={(next) => repostMutation.mutate(next)}
              Icon={RepostIcon}
              quantity={postCounts.reposts}
              color="accent"
              compact
            />
            <ToggleStepper
              isSelected={isLiked}
              aria-label={isLiked ? t('取消点赞', 'Unlike post') : t('点赞', 'Like post')}
              onChange={handleLikeToggle}
              Icon={SvgHeart}
              quantity={numberOfLikes}
              color="accent"
              compact
            />
            <Link
              href={postHref(postId)}
              aria-label={`${formatCount(viewCount)} ${t('次浏览', 'views')}`}
              className="flex min-w-12 items-center gap-2 rounded-full px-2 py-1 text-xs font-medium hover:bg-primary/10 hover:text-primary">
              <AnalyticsIcon className="h-5 w-5" />
              {formatCount(viewCount)}
            </Link>
            <button
              type="button"
              aria-label={isBookmarked ? t('取消收藏', 'Remove bookmark') : t('收藏', 'Bookmark')}
              aria-pressed={isBookmarked}
              onClick={() => (isBookmarked ? removeBookmarkMutation.mutate() : bookmarkMutation.mutate())}
              disabled={bookmarkMutation.isPending || removeBookmarkMutation.isPending}
              className="flex h-8 min-w-10 items-center justify-center gap-1 rounded-full px-2 text-muted-foreground transition-colors hover:bg-primary/10 hover:text-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:opacity-50">
              <SvgBookmark className={cn('h-5 w-5', isBookmarked && 'fill-primary stroke-primary')} />
              <span className="text-xs font-medium">{formatCount(postCounts.bookmarks)}</span>
            </button>
            <button
              type="button"
              aria-label={t('分享帖子', 'Share post')}
              onClick={sharePost}
              className="grid h-8 w-8 place-items-center rounded-full text-muted-foreground transition-colors hover:bg-primary/10 hover:text-primary">
              <ShareIcon className="h-5 w-5" />
            </button>
            {!isOwnPost && (
              <button
                type="button"
                onClick={reportPost}
                className="px-2 py-1 text-xs hover:text-destructive"
                aria-label={t('举报动态', 'Report post')}>
                {t('举报', 'Report')}
              </button>
            )}
          </div>
        </div>

        <AnimatePresence>
          {commentsShown && (
            <motion.div
              data-post-interactive
              key={`${postId}-comments`}
              variants={variants}
              initial={false}
              animate="animate"
              exit="exit">
              <Comments postId={postId} />
            </motion.div>
          )}
        </AnimatePresence>
      </article>
    );
  },
  (oldProps, newProps) => isEqual(oldProps, newProps),
);

Post.displayName = 'Post';
