'use client';

import { Key, useCallback, useMemo, useState } from 'react';
import { Activity } from '@/components/Activity';
import { AllCaughtUp } from '@/components/AllCaughtUp';
import { useNotificationsReadStatusMutations } from '@/hooks/mutations/useNotificationsReadStatusMutations';
import { useNotificationsQuery } from '@/hooks/queries/useNotificationsQuery';
import { DropdownMenuButton } from '@/components/ui/DropdownMenuButton';
import { Section, Item } from 'react-stately';
import { GenericLoading } from '@/components/GenericLoading';
import { SomethingWentWrong } from '@/components/SometingWentWrong';
import { PageHeader } from '@/components/ui/PageHeader';
import { cn } from '@/lib/cn';
import { useLanguage } from '@/hooks/useLanguage';
import type { ApiNotificationType } from '@/lib/backend/types';

type Tab = 'all' | ApiNotificationType;

export function Notifications() {
  const { t } = useLanguage();
  const [tab, setTab] = useState<Tab>('all');
  const { data, isPending, isError } = useNotificationsQuery();
  const { markAllAsReadMutation } = useNotificationsReadStatusMutations();

  const tabs: { key: Tab; label: string }[] = [
    { key: 'all', label: t('全部', 'All') },
    { key: 'comment', label: t('评论', 'Comments') },
    { key: 'reply', label: t('回复', 'Replies') },
    { key: 'like', label: t('赞', 'Likes') },
    { key: 'favorite', label: t('收藏', 'Saves') },
    { key: 'system', label: t('系统', 'System') },
  ];
  const unreadOf = (key: Tab) =>
    !data
      ? 0
      : key === 'all'
      ? data.unreadCount
      : key === 'system'
      ? (data.unreadByType.system || 0) + (data.unreadByType.report_result || 0)
      : data.unreadByType[key] || 0;
  const items = useMemo(
    () =>
      (data?.items ?? []).filter(
        (item) => tab === 'all' || item.category === tab || (tab === 'system' && item.category === 'report_result'),
      ),
    [data, tab],
  );

  const nothingUnread = unreadOf(tab) === 0;
  const disabledKeys = useMemo(() => (nothingUnread ? ['mark-all'] : []), [nothingUnread]);

  const markAllAsRead = useCallback(
    (key: Key) => {
      if (key !== 'mark-all') return;
      if (tab === 'system') {
        markAllAsReadMutation.mutate('system');
        markAllAsReadMutation.mutate('report_result');
      } else {
        markAllAsReadMutation.mutate(tab === 'all' ? undefined : tab);
      }
    },
    [markAllAsReadMutation, tab],
  );

  return (
    <div>
      <PageHeader
        title={t('通知', 'Notifications')}
        sticky
        action={
          <DropdownMenuButton
            key="notifications-option"
            label={t('通知选项', 'Notification options')}
            onAction={markAllAsRead}
            disabledKeys={disabledKeys}>
            <Section>
              <Item key="mark-all">{t('全部标为已读', 'Mark all as read')}</Item>
            </Section>
          </DropdownMenuButton>
        }
      />
      <div className="flex gap-1 overflow-x-auto border-b border-border px-3">
        {tabs.map(({ key, label }) => (
          <button
            key={key}
            type="button"
            onClick={() => setTab(key)}
            className={cn(
              'relative shrink-0 px-3 py-3 text-sm font-medium text-muted-foreground',
              tab === key &&
                'text-foreground after:absolute after:inset-x-3 after:bottom-0 after:h-0.5 after:bg-primary',
            )}>
            {label}
            {unreadOf(key) > 0 && <span className="ml-1 text-xs text-primary">{unreadOf(key)}</span>}
          </button>
        ))}
      </div>
      {isPending ? (
        <GenericLoading>{t('正在加载通知', 'Loading notifications')}</GenericLoading>
      ) : isError ? (
        <SomethingWentWrong />
      ) : (
        <>
          {items.map((activity) => (
            <Activity key={activity.id} {...activity} />
          ))}
          <AllCaughtUp />
        </>
      )}
    </div>
  );
}
