'use client';

import { useCallback, useEffect, useState } from 'react';
import { useLanguage } from '@/hooks/useLanguage';

type ModerationCaseItem = {
  id: string;
  notes: string | null;
  createdAt: string;
  openedBy: { id: string; username: string | null; name: string | null } | null;
  post: {
    id: number;
    content: string | null;
    createdAt: string;
    user: { id: string; username: string | null; name: string | null };
    visualMedia: Array<{ type: 'PHOTO' | 'VIDEO'; url: string | null }>;
  };
};

export function ModerationQueue() {
  const { language, t } = useLanguage();
  const [items, setItems] = useState<ModerationCaseItem[]>([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [workingId, setWorkingId] = useState('');

  const reload = useCallback(async () => {
    const response = await fetch('/api/admin/moderation/cases', { cache: 'no-store' });
    const payload = (await response.json()) as { data?: { items?: ModerationCaseItem[] }; message?: string };
    if (!response.ok)
      throw new Error(payload.message || t('审核队列加载失败。', 'Could not load the moderation queue.'));
    setItems(payload.data?.items || []);
    setError('');
  }, [t]);

  useEffect(() => {
    reload()
      .catch((reason: Error) => setError(reason.message))
      .finally(() => setLoading(false));
  }, [reload]);

  async function decide(caseId: string, decision: 'approve' | 'remove') {
    setWorkingId(caseId);
    try {
      const response = await fetch(`/api/admin/moderation/cases/${caseId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ decision }),
      });
      const payload = (await response.json()) as { message?: string };
      if (!response.ok) throw new Error(payload.message || t('审核操作失败。', 'Moderation action failed.'));
      await reload();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : t('审核操作失败。', 'Moderation action failed.'));
    } finally {
      setWorkingId('');
    }
  }

  if (loading)
    return (
      <p className="px-5 py-10 text-sm text-muted-foreground">{t('正在加载审核队列…', 'Loading moderation queue…')}</p>
    );
  if (error && items.length === 0) return <p className="px-5 py-10 text-sm text-muted-foreground">{error}</p>;
  if (items.length === 0)
    return (
      <p className="px-5 py-10 text-sm text-muted-foreground">
        {t('当前没有待审核动态。', 'There are no posts to review.')}
      </p>
    );

  return (
    <div>
      {error && <p className="border-b border-border px-5 py-3 text-sm text-destructive">{error}</p>}
      {items.map((item) => (
        <article key={item.id} className="border-b border-border px-4 py-5 sm:px-5">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-sm font-semibold">
                {item.post.user.name || item.post.user.username || t('用户', 'User')}
              </p>
              <p className="mt-1 text-xs text-muted-foreground">
                {new Date(item.createdAt).toLocaleString(language === 'zh' ? 'zh-CN' : 'en-US')} · {t('帖子', 'Post')} #
                {item.post.id}
              </p>
            </div>
            <span className="rounded-full bg-amber-500/10 px-2.5 py-1 text-xs font-medium text-amber-700 dark:text-amber-300">
              {t('待审核', 'Pending review')}
            </span>
          </div>
          <p className="mt-4 whitespace-pre-wrap break-words text-sm leading-6">
            {item.post.content || t('（仅含附件）', '(Media only)')}
          </p>
          {item.post.visualMedia.length > 0 && (
            <div className="mt-4 flex flex-wrap gap-3">
              {item.post.visualMedia.map((media) =>
                media.type === 'PHOTO' && media.url ? (
                  <img
                    key={media.url}
                    src={media.url}
                    alt={t('待审核附件', 'Attachment pending review')}
                    className="max-h-72 max-w-full rounded-md object-contain"
                  />
                ) : media.url ? (
                  <a
                    key={media.url}
                    href={media.url}
                    target="_blank"
                    rel="noreferrer"
                    className="text-sm text-primary underline">
                    {t('查看视频附件', 'View video attachment')}
                  </a>
                ) : null,
              )}
            </div>
          )}
          <p className="mt-4 rounded-md bg-secondary/60 px-3 py-2 text-xs leading-5 text-muted-foreground">
            {item.notes || t('没有附加审核说明。', 'No additional review notes.')}
          </p>
          <div className="mt-4 flex gap-2">
            <button
              type="button"
              disabled={workingId === item.id}
              onClick={() => decide(item.id, 'approve')}
              className="rounded-full bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground disabled:opacity-50">
              {t('通过并公开', 'Approve and publish')}
            </button>
            <button
              type="button"
              disabled={workingId === item.id}
              onClick={() => decide(item.id, 'remove')}
              className="rounded-full border border-border px-4 py-2 text-sm font-semibold text-foreground disabled:opacity-50">
              {t('移除动态', 'Remove post')}
            </button>
          </div>
        </article>
      ))}
    </div>
  );
}
