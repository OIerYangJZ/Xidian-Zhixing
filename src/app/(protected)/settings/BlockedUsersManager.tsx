'use client';

import Link from 'next/link';
import { FormEvent, useState } from 'react';
import { useSession } from 'next-auth/react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useLanguage } from '@/hooks/useLanguage';

type UserSummary = { id: string; username: string; name: string; profilePhoto: string | null };
type BlockedUser = UserSummary & { createdAt: string };

export function BlockedUsersManager() {
  const { data: session } = useSession();
  const { t } = useLanguage();
  const queryClient = useQueryClient();
  const userId = session?.user?.id;
  const [search, setSearch] = useState('');
  const [results, setResults] = useState<UserSummary[]>([]);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState('');
  const {
    data: blockedUsers = [],
    isError: blockedUsersFailed,
    isPending,
  } = useQuery<BlockedUser[]>({
    queryKey: ['blocked-users', userId],
    enabled: Boolean(userId),
    queryFn: async () => {
      const response = await fetch(`/api/users/${userId}/blocks`);
      if (!response.ok) throw new Error('Could not load blocked users.');
      return response.json() as Promise<BlockedUser[]>;
    },
  });

  const searchUsers = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError('');
    const keyword = search.trim();
    if (!keyword) {
      setResults([]);
      return;
    }
    setResults([]);
    const response = await fetch(`/api/users-basic?search=${encodeURIComponent(keyword)}`);
    if (!response.ok) {
      setError(t('搜索同学失败，请重试。', 'Could not search for users. Try again.'));
      return;
    }
    const found = (await response.json()) as UserSummary[];
    const blockedIds = new Set(blockedUsers.map((blocked) => blocked.id));
    setResults(found.filter((candidate) => !blockedIds.has(candidate.id)));
  };

  const blockUser = async (target: UserSummary) => {
    if (!userId) return;
    setBusyId(target.id);
    setError('');
    const response = await fetch(`/api/users/${userId}/blocks`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ blockedId: target.id }),
    });
    if (!response.ok) {
      setError(t('屏蔽失败，请重试。', 'Could not block this account. Try again.'));
      setBusyId(null);
      return;
    }
    setResults((current) => current.filter((candidate) => candidate.id !== target.id));
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ['blocked-users', userId] }),
      queryClient.invalidateQueries({ queryKey: ['discover'] }),
      queryClient.invalidateQueries({ queryKey: ['posts'] }),
      queryClient.invalidateQueries({
        predicate: ({ queryKey }) => queryKey[0] === 'users' && queryKey[2] === 'posts',
      }),
    ]);
    setBusyId(null);
  };

  const unblockUser = async (target: BlockedUser) => {
    if (!userId) return;
    setBusyId(target.id);
    setError('');
    const response = await fetch(`/api/users/${userId}/blocks/${target.id}`, { method: 'DELETE' });
    if (!response.ok) {
      setError(t('解除屏蔽失败，请重试。', 'Could not unblock this account. Try again.'));
      setBusyId(null);
      return;
    }
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ['blocked-users', userId] }),
      queryClient.invalidateQueries({ queryKey: ['discover'] }),
      queryClient.invalidateQueries({ queryKey: ['posts'] }),
      queryClient.invalidateQueries({
        predicate: ({ queryKey }) => queryKey[0] === 'users' && queryKey[2] === 'posts',
      }),
    ]);
    setBusyId(null);
  };

  return (
    <div>
      <section className="border-b border-border px-4 py-4 sm:px-5">
        <p className="mt-1 text-sm text-muted-foreground">
          {t(
            '搜索知行用户并屏蔽。屏蔽后会互相取消关注，并停止出现在彼此的信息流和私信中。',
            'Search for a Zhixing account to block. Blocking removes both follow relationships and hides each other from feeds and messages.',
          )}
        </p>
        <form onSubmit={searchUsers} className="mt-4 flex gap-2">
          <input
            aria-label={t('搜索同学', 'Search users')}
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder={t('姓名或用户名', 'Name or username')}
            className="min-h-11 min-w-0 flex-1 rounded-full border border-border bg-background px-4 text-sm outline-none focus-visible:ring-2 focus-visible:ring-primary"
          />
          <button
            type="submit"
            className="min-h-11 rounded-full bg-primary px-5 text-sm font-semibold text-primary-foreground">
            {t('搜索', 'Search')}
          </button>
        </form>
        {results.length > 0 && (
          <ul className="mt-3 divide-y divide-border rounded-md border border-border">
            {results.map((candidate) => (
              <li key={candidate.id} className="flex items-center gap-3 px-3 py-3">
                <span
                  aria-hidden="true"
                  className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-secondary text-sm">
                  {candidate.name.slice(0, 1)}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-semibold">{candidate.name}</span>
                  <span className="block truncate text-xs text-muted-foreground">@{candidate.username}</span>
                </span>
                <button
                  type="button"
                  disabled={busyId === candidate.id}
                  onClick={() => blockUser(candidate)}
                  className="min-h-10 rounded-full border border-border px-4 text-sm font-semibold hover:bg-secondary disabled:opacity-50">
                  {t('屏蔽', 'Block')}
                </button>
              </li>
            ))}
          </ul>
        )}
        {search.trim() && results.length === 0 && (
          <p className="mt-3 text-sm text-muted-foreground">
            {t('没有找到可屏蔽的同学。', 'No accounts found to block.')}
          </p>
        )}
        {error && (
          <p role="alert" className="mt-3 text-sm text-destructive">
            {error}
          </p>
        )}
      </section>

      <section aria-labelledby="blocked-users-heading">
        <h2 id="blocked-users-heading" className="px-4 py-4 text-base font-semibold sm:px-5">
          {t('已屏蔽的账号', 'Blocked accounts')}
        </h2>
        {blockedUsersFailed ? (
          <p role="alert" className="border-t border-border px-4 py-5 text-sm text-destructive">
            {t('屏蔽列表加载失败，请刷新重试。', 'Could not load blocked accounts. Refresh and try again.')}
          </p>
        ) : isPending ? (
          <p className="px-4 py-5 text-sm text-muted-foreground">{t('正在加载…', 'Loading…')}</p>
        ) : blockedUsers.length === 0 ? (
          <p className="border-t border-border px-4 py-8 text-center text-sm text-muted-foreground">
            {t('你还没有屏蔽任何账号。', 'You have not blocked any accounts.')}
          </p>
        ) : (
          <ul className="divide-y divide-border">
            {blockedUsers.map((blocked) => (
              <li key={blocked.id} className="flex items-center gap-3 px-4 py-3 sm:px-5">
                <Link
                  href={`/${blocked.username}`}
                  aria-label={blocked.name}
                  className="flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-full bg-secondary text-sm">
                  {blocked.profilePhoto ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={blocked.profilePhoto} alt="" className="h-full w-full object-cover" />
                  ) : (
                    blocked.name.slice(0, 1)
                  )}
                </Link>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-semibold">{blocked.name}</span>
                  <span className="block truncate text-xs text-muted-foreground">@{blocked.username}</span>
                </span>
                <button
                  type="button"
                  disabled={busyId === blocked.id}
                  onClick={() => unblockUser(blocked)}
                  className="min-h-10 rounded-full border border-border px-4 text-sm font-semibold hover:bg-secondary disabled:opacity-50">
                  {t('解除屏蔽', 'Unblock')}
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
