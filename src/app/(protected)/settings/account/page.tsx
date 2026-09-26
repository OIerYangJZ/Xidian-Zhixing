'use client';

import { useSession } from 'next-auth/react';
import Link from 'next/link';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';
import { useSessionUserData } from '@/hooks/useSessionUserData';

export default function AccountSettingsPage() {
  const { data: session } = useSession();
  const [profile] = useSessionUserData();
  const { t } = useLanguage();
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
