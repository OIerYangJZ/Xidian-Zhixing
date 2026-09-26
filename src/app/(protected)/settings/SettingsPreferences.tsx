'use client';

import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useLanguage } from '@/hooks/useLanguage';
import { PageHeader } from '@/components/ui/PageHeader';

type SettingsData = {
  privacy: { allowStrangerDm: boolean; showContactable: boolean };
  notifications: {
    follows: boolean;
    likes: boolean;
    comments: boolean;
    messages: boolean;
    replies: boolean;
    favorites: boolean;
    reportResults: boolean;
    system: boolean;
  };
};

export function SettingsPreferences({ section }: { section: 'privacy' | 'notifications' }) {
  const { t } = useLanguage();
  const qc = useQueryClient();
  const { data, isPending } = useQuery<SettingsData>({
    queryKey: ['settings'],
    queryFn: async () => {
      const response = await fetch('/api/settings');
      if (!response.ok) throw new Error('Settings could not be loaded.');
      return response.json() as Promise<SettingsData>;
    },
  });
  const toggle = async (group: 'privacy' | 'notifications', key: string, checked: boolean) => {
    await fetch('/api/settings', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ [group]: { [key]: checked } }),
    });
    await qc.invalidateQueries({ queryKey: ['settings'] });
  };

  const privacyItems = [
    {
      key: 'allowStrangerDm',
      title: t('允許陌生同學私信', 'Allow direct messages from people you do not follow'),
      detail: t('关闭后，只有你关注的同学可以发起私信。', 'When off, only people you follow can start a conversation.'),
    },
    {
      key: 'showContactable',
      title: t('在个人主页显示可联系状态', 'Show that you are open to being contacted'),
      detail: t('让其他同学知道可以通过知行联系你。', 'Let other students know they can contact you on Zhixing.'),
    },
  ] as const;
  const notificationItems = [
    { key: 'follows', title: t('新关注', 'New followers') },
    { key: 'comments', title: t('帖子评论', 'Post comments') },
    { key: 'replies', title: t('评论回复', 'Comment replies') },
    { key: 'likes', title: t('点赞', 'Likes') },
    { key: 'favorites', title: t('收藏', 'Bookmarks') },
    { key: 'messages', title: t('私信', 'Direct messages') },
    { key: 'reportResults', title: t('举报处理结果', 'Report outcomes') },
    { key: 'system', title: t('系统通知', 'System notifications') },
  ] as const;

  const items = section === 'privacy' ? privacyItems : notificationItems;
  const values = (section === 'privacy' ? data?.privacy : data?.notifications) as Record<string, boolean> | undefined;
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
      ) : (
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
      )}
    </div>
  );
}
