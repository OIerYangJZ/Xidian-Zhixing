'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { useLanguage } from '@/hooks/useLanguage';
import { GetUser } from '@/types/definitions';
import { ProfilePhoto } from './ui/ProfilePhoto';
import { ProfileActionButtons } from './ProfileActionButtons';

export function SuggestedFollows() {
  const { t } = useLanguage();
  const { data: users = [] } = useQuery<GetUser[]>({
    queryKey: ['suggested-follows'],
    queryFn: async () => {
      const response = await fetch('/api/users?recommendations=true&limit=3');
      if (!response.ok) throw new Error('推荐关注加载失败');
      return response.json() as Promise<GetUser[]>;
    },
    staleTime: 60000 * 5,
  });

  if (!users.length) return null;
  return (
    <section className="quiet-surface overflow-hidden rounded-lg">
      <h2 className="px-4 py-3 text-base font-semibold">{t('推荐关注', 'Who to follow')}</h2>
      {users.map((user) => (
        <div key={user.id} className="flex items-center gap-3 border-t border-border/70 px-4 py-3">
          <div className="h-10 w-10 shrink-0">
            <ProfilePhoto name={user.name} username={user.username} photoUrl={user.profilePhoto} />
          </div>
          <div className="min-w-0 flex-1">
            <Link href={`/${user.username}`} className="block truncate text-sm font-semibold hover:underline">
              {user.name}
            </Link>
            <span className="block truncate text-xs text-muted-foreground">@{user.username}</span>
          </div>
          <ProfileActionButtons targetUserId={user.id} />
        </div>
      ))}
    </section>
  );
}
