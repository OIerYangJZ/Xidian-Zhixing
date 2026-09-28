'use client';

import { useMe } from '@/lib/backend/session';
import { updateNotificationPreferences, updatePrivacy } from '@/lib/backend/endpoints';
import { useState } from 'react';
import { useLanguage } from '@/hooks/useLanguage';
import { PageHeader } from '@/components/ui/PageHeader';

export function SettingsPreferences({ section }: { section: 'privacy' | 'notifications' }) {
  const { t } = useLanguage();
  const { me, status, refresh } = useMe();
  const [saveError, setSaveError] = useState('');
  const [pending, setPending] = useState<Record<string, boolean>>({});
  const isPending = status === 'loading';
  const toggle = async (group: 'privacy' | 'notifications', key: string, checked: boolean) => {
    setSaveError('');
    setPending((current) => ({ ...current, [key]: checked }));
    try {
      if (group === 'privacy') await updatePrivacy({ [key]: checked });
      else await updateNotificationPreferences({ [key]: checked });
      await refresh();
    } catch {
      setSaveError(t('设置保存失败，请重试。', 'Settings could not be saved. Please try again.'));
    } finally {
      setPending((current) => {
        const next = { ...current };
        delete next[key];
        return next;
      });
    }
  };

  const privacyItems = [
    {
      key: 'allowStrangerDm',
      title: t('允许陌生同学私信', 'Allow direct messages from people you do not follow'),
      detail: t('关闭后，只有你关注的同学可以发起私信。', 'When off, only people you follow can start a conversation.'),
    },
    {
      key: 'showContactable',
      title: t('在个人主页显示可联系状态', 'Show that you are open to being contacted'),
      detail: t('让其他同学知道可以通过知行联系你。', 'Let other students know they can contact you on Zhixing.'),
    },
  ] as const;
  const notificationItems = [
    { key: 'notifyComment', title: t('帖子评论', 'Post comments') },
    { key: 'notifyReply', title: t('评论回复', 'Comment replies') },
    { key: 'notifyLike', title: t('点赞', 'Likes') },
    { key: 'notifyFavorite', title: t('收藏', 'Bookmarks') },
    { key: 'notifyRepost', title: t('转发', 'Reposts') },
    { key: 'notifyMention', title: t('@我', 'Mentions') },
    { key: 'notifyReportResult', title: t('举报处理结果', 'Report outcomes') },
    { key: 'notifySystem', title: t('系统通知', 'System notifications') },
  ] as const;

  const items = section === 'privacy' ? privacyItems : notificationItems;
  const data = me;
  const values = { ...(me as unknown as Record<string, boolean> | null), ...pending };
  const heading =
    section === 'privacy' ? t('隐私和安全', 'Privacy and safety') : t('通知偏好', 'Notification preferences');
  return (
    <div>
      <PageHeader title={heading} sticky />
      <p className="border-b border-border px-4 py-4 text-sm text-muted-foreground">
        {section === 'privacy'
          ? t('控制其他同学如何与你联系。', 'Control how other students can contact you.')
          : t('选择你希望收到的通知。', 'Choose which notifications you want to receive.')}
      </p>
      {isPending ? (
        <p className="px-4 py-6 text-sm text-muted-foreground">{t('正在加载设置…', 'Loading settings…')}</p>
      ) : data ? (
        <>
          {saveError && (
            <p role="alert" className="px-4 py-3 text-sm text-destructive-foreground">
              {saveError}
            </p>
          )}
          <div className="divide-y divide-border">
            {items.map((item) => (
              <label
                key={item.key}
                className="flex cursor-pointer items-start justify-between gap-4 px-4 py-4 hover:bg-secondary/40">
                <span>
                  <span className="block text-sm font-medium">{item.title}</span>
                  {'detail' in item && <span className="mt-1 block text-sm text-muted-foreground">{item.detail}</span>}
                </span>
                <input
                  type="checkbox"
                  checked={Boolean(values?.[item.key])}
                  onChange={(event) => {
                    toggle(section, item.key, event.target.checked);
                  }}
                  className="mt-0.5 h-5 w-5 accent-primary"
                />
              </label>
            ))}
          </div>
        </>
      ) : (
        <p role="alert" className="px-4 py-6 text-sm text-destructive-foreground">
          {t('设置加载失败，请刷新页面重试。', 'Settings could not be loaded. Refresh and try again.')}
        </p>
      )}
    </div>
  );
}
