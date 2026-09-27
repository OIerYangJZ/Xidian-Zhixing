'use client';

import Link from 'next/link';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';
import { useDialogs } from '@/hooks/useDialogs';
import { useToast } from '@/hooks/useToast';
import { useAuthActions, useMe } from '@/lib/backend/session';
import { ApiError } from '@/lib/backend/client';
import { getMyAppeal, requestAccountCancellation, submitBanAppeal } from '@/lib/backend/endpoints';

const APPEAL_STATUS: Record<string, [string, string]> = {
  pending: ['处理中', 'Pending'],
  approved: ['已通过', 'Approved'],
  rejected: ['未通过', 'Rejected'],
  closed: ['已关闭', 'Closed'],
};

export default function AccountSettingsPage() {
  const { me } = useMe();
  const { signOut } = useAuthActions();
  const { t } = useLanguage();
  const { prompt, confirm } = useDialogs();
  const { showToast } = useToast();
  const qc = useQueryClient();
  const [appealing, setAppealing] = useState(false);
  const { data: appealState } = useQuery({ queryKey: ['appeals', 'mine'], queryFn: getMyAppeal });

  const submitAppeal = () => {
    if (!me) return;
    prompt({
      title: t('申请解封', 'Appeal the ban'),
      message: t(
        '说明你认为处理需要复核的原因，每次封禁可在站内申诉一次。',
        'Explain why the ban should be reviewed. One in-app appeal per ban.',
      ),
      promptType: 'textarea',
      onSubmit: async (content) => {
        setAppealing(true);
        try {
          await submitBanAppeal(me.email, content);
          await qc.invalidateQueries({ queryKey: ['appeals', 'mine'] });
          showToast({ title: t('申诉已提交', 'Appeal submitted'), type: 'success' });
        } catch (error) {
          showToast({
            title: t('申诉提交失败', 'Could not submit appeal'),
            message: error instanceof ApiError ? error.message : undefined,
            type: 'error',
          });
        } finally {
          setAppealing(false);
        }
      },
    });
  };

  const cancelAccount = () => {
    prompt({
      title: t('申请注销账号', 'Request account deletion'),
      message: t(
        '注销申请由管理员审核，通过后账号和公开内容将不再显示。可以说明原因（选填）。',
        'An admin reviews the request; once approved your account and public content are removed. Reason (optional):',
      ),
      promptType: 'textarea',
      onSubmit: async (reason) => {
        try {
          await requestAccountCancellation(reason.trim() || undefined);
          showToast({ title: t('注销申请已提交', 'Deletion requested'), type: 'success' });
        } catch (error) {
          showToast({
            title: t('申请失败', 'Request failed'),
            message: error instanceof ApiError ? error.message : undefined,
            type: 'error',
          });
        }
      },
    });
  };

  const appeal = appealState?.appeal;
  const rows: [string, string][] = [
    [t('昵称', 'Name'), me?.nickname || '—'],
    [t('学号', 'Student ID'), me?.studentId || '—'],
    [t('学院', 'College'), me?.college || '—'],
    [t('用户等级', 'Level'), me?.userLevelLabel || '—'],
    [t('登录方式', 'Sign-in method'), t('西电统一身份认证', 'Xidian single sign-on')],
  ];

  return (
    <div>
      <PageHeader title={t('账号信息和安全', 'Account information and security')} sticky />
      <section className="space-y-4 px-4 py-5">
        {me?.banned && (
          <div className="rounded-lg border border-destructive/40 bg-destructive/5 p-4 text-sm">
            <h2 className="font-semibold text-destructive">{t('账号已被封禁', 'This account is banned')}</h2>
            <p className="mt-1 text-muted-foreground">
              {t('封禁期间只能查看本页并提交解封申诉。', 'While banned you can only view this page and appeal.')}
            </p>
            {appeal && (
              <p className="mt-2">
                {t('申诉状态：', 'Appeal: ')}
                {t(...(APPEAL_STATUS[appeal.status] || [appeal.status, appeal.status]))}
                {appeal.adminNote && <span className="block text-muted-foreground">{appeal.adminNote}</span>}
              </p>
            )}
            {appealState?.canSubmit ? (
              <button
                type="button"
                disabled={appealing}
                onClick={submitAppeal}
                className="mt-3 inline-flex min-h-10 items-center rounded-full bg-primary px-4 text-sm font-medium text-primary-foreground disabled:opacity-50">
                {t('申请解封', 'Appeal')}
              </button>
            ) : (
              appealState?.supportEmail && (
                <p className="mt-2 text-muted-foreground">
                  {t('如需进一步申诉，请发送邮件至 ', 'For further appeals, email ')}
                  <a className="text-primary underline" href={`mailto:${appealState.supportEmail}`}>
                    {appealState.supportEmail}
                  </a>
                </p>
              )
            )}
          </div>
        )}
        <div>
          <h2 className="text-base font-semibold">{t('账号信息', 'Account information')}</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            {t('通过西电统一身份认证登录知行。', 'Your Zhixing account uses Xidian single sign-on.')}
          </p>
        </div>
        <dl className="divide-y divide-border border-y border-border text-sm">
          {rows.map(([label, value]) => (
            <div key={label} className="flex justify-between gap-4 py-3">
              <dt className="text-muted-foreground">{label}</dt>
              <dd>{value}</dd>
            </div>
          ))}
        </dl>
        {!me?.banned && (
          <Link
            href="/edit-profile"
            className="inline-flex min-h-11 items-center rounded-full border border-border px-4 text-sm font-medium hover:bg-secondary">
            {t('编辑个人资料', 'Edit profile')}
          </Link>
        )}
        <p className="text-xs leading-5 text-muted-foreground">
          {t(
            '密码和认证信息由西电统一身份认证管理。',
            'Passwords and authentication details are managed by Xidian single sign-on.',
          )}
        </p>
        <div className="flex flex-wrap gap-3 border-t border-border pt-4">
          {me?.banned && (
            <button
              type="button"
              onClick={() =>
                confirm({
                  title: t('退出登录', 'Log out'),
                  message: t('确定退出西电知行吗？', 'Log out of Zhixing?'),
                  onConfirm: () => signOut(),
                })
              }
              className="text-sm text-muted-foreground hover:text-foreground">
              {t('退出登录', 'Log out')}
            </button>
          )}
          {!me?.banned && (
            <button type="button" onClick={cancelAccount} className="text-sm text-destructive hover:underline">
              {t('申请注销账号', 'Request account deletion')}
            </button>
          )}
        </div>
      </section>
    </div>
  );
}
