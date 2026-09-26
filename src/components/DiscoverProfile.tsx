'use client';

import { ProfileActionButtons } from '@/components/ProfileActionButtons';
import { ProfilePhoto } from '@/components/ui/ProfilePhoto';
import { memo } from 'react';
import { useUserQuery } from '@/hooks/queries/useUserQuery';
import { useSession } from 'next-auth/react';
import Link from 'next/link';

export const DiscoverProfile = memo(
  ({ userId }: { userId: string }) => {
    const { data: user, isPending, isError } = useUserQuery(userId);
    const { data: session } = useSession();

    if (isPending) return <div className="feed-separator h-20 animate-pulse border-b bg-secondary/30" />;
    if (isError || !user) return null;

    return (
      <article className="feed-separator flex items-center gap-3 border-b px-4 py-4 sm:px-5">
        <div className="h-12 w-12 shrink-0">
          <ProfilePhoto
            name={user.name}
            username={user.username}
            photoUrl={user.profilePhoto}
            fallbackAvatarClassName="text-xl"
          />
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex min-w-0 items-center gap-1.5">
            <Link href={`/${user.username}`} className="truncate text-sm font-semibold hover:underline">
              {user.name}
            </Link>
            <span className="truncate text-xs text-muted-foreground">@{user.username}</span>
          </div>
          <p className="mt-1 line-clamp-2 text-sm leading-5 text-foreground/85">{user.bio || '还没有填写个人介绍。'}</p>
          <p className="mt-1.5 text-xs text-muted-foreground">
            {user.followerCount} 粉丝 <span aria-hidden="true">·</span> {user.followingCount} 关注
          </p>
        </div>
        {session?.user.id !== user.id && <ProfileActionButtons targetUserId={user.id} />}
      </article>
    );
  },
  (prevProps, nextProps) => prevProps.userId === nextProps.userId,
);

DiscoverProfile.displayName = 'DiscoverProfile';
