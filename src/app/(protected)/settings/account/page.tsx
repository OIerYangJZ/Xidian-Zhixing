'use client';

import { useSession } from 'next-auth/react';
import Link from 'next/link';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';
import { useSessionUserData } from '@/hooks/useSessionUserData';
import { useDialogs } from '@/hooks/useDialogs';
import { useToast } from '@/hooks/useToast';
import { useEffect, useState } from 'react';

type AppealCase = {
  id: string;
  action: string;
  postId: number | null;
  commentId: number | null;
  appeals: Array<{ id: string; resolvedAt: string | null }>;
};

export default function AccountSettingsPage() {
  const { data: session } = useSession();
  const [profile] = useSessionUserData();
  const { t } = useLanguage();
  const { prompt } = useDialogs();
  const { showToast } = useToast();
  const [cases, setCases] = useState<AppealCase[]>([]);
  useEffect(() => {
    fetch('/api/appeals')
      .then((response) => (response.ok ? response.json() : []))
      .then(setCases);
  }, []);
  const submitAppeal = (caseId: string) => {
    prompt({
      title: t('提交申诉', 'Submit appeal'),
      message: t('说明你认为处理需要复核的原因。', 'Explain why this decision needs review.'),
      promptType: 'textarea',
      onSubmit: async (reason) => {
        const response = await fetch('/api/appeals', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ caseId, reason }),
        });
        if (response.ok)
          setCases((items) =>
            items.map((item) => (item.id === caseId ? { ...item, appeals: [{ id: caseId, resolvedAt: null }] } : item)),
          );
        showToast({
          title: response.ok ? t('申诉已提交', 'Appeal submitted') : t('申诉提交失败', 'Could not submit appeal'),
          type: response.ok ? 'success' : 'error',
        });
      },
    });
  };
  return (
    <div>
      <PageHeader title={t('账号信息和安全', 'Account information and security')} sticky />
      <section className="space-y-4 px-4 py-5">
        <div>
          <h2 className="text-base font-semibold">{t('账号信息', 'Account information')}</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            {t('通过西电统一身份认证登录知行。', 'Your Zhixing account uses Xidian single sign-on.')}
          </p>
        </div>
        <dl className="divide-y divide-border border-y border-border text-sm">
          <div className="flex justify-between gap-4 py-3">
            <dt className="text-muted-foreground">{t('姓名', 'Name')}</dt>
            <dd>{session?.user.name || '—'}</dd>
          </div>
          <div className="flex justify-between gap-4 py-3">
            <dt className="text-muted-foreground">{t('用户名', 'Username')}</dt>
            <dd>@{profile?.username || '—'}</dd>
          </div>
          <div className="flex justify-between gap-4 py-3">
            <dt className="text-muted-foreground">{t('登录方式', 'Sign-in method')}</dt>
            <dd>{t('西电统一身份认证', 'Xidian single sign-on')}</dd>
          </div>
        </dl>
        {cases.length > 0 && (
          <div className="space-y-2 border-y border-border py-4">
            <h2 className="text-sm font-semibold">{t('内容处理与申诉', 'Moderation and appeals')}</h2>
            {cases.map((item) => (
              <div key={item.id} className="flex items-center justify-between gap-3 text-sm">
                <span>
                  {item.postId ? `${t('帖子', 'Post')} #${item.postId}` : `${t('评论', 'Comment')} #${item.commentId}`}{' '}
                  ·{' '}
                  {item.action === 'SUSPEND_USER'
                    ? t('账号停用', 'Account suspended')
                    : t('内容移除', 'Content removed')}
                </span>
                {item.appeals.length === 0 ? (
                  <button type="button" onClick={() => submitAppeal(item.id)} className="text-primary underline">
                    {t('申诉', 'Appeal')}
                  </button>
                ) : (
                  <span className="text-muted-foreground">
                    {item.appeals[0].resolvedAt
                      ? t('申诉已处理', 'Appeal reviewed')
                      : t('申诉处理中', 'Appeal pending')}
                  </span>
                )}
              </div>
            ))}
          </div>
        )}
        <Link
          href="/edit-profile"
          className="inline-flex min-h-11 items-center rounded-full border border-border px-4 text-sm font-medium hover:bg-secondary">
          {t('编辑个人资料', 'Edit profile')}
        </Link>
        <p className="text-xs leading-5 text-muted-foreground">
          {t(
            '密码和认证信息由西电统一身份认证管理。',
            'Passwords and authentication details are managed by Xidian single sign-on.',
          )}
        </p>
      </section>
    </div>
  );
}
