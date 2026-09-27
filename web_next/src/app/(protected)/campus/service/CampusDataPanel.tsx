'use client';

import { useQuery } from '@tanstack/react-query';
import { useLanguage } from '@/hooks/useLanguage';
import { CampusAuthPanels } from './CampusAuthPanels';

type ServiceInfo = {
  status: 'pending' | 'available';
  authReady: boolean;
  emptyText: string;
  requiredAccess: string[];
  slug: string;
};

export function CampusDataPanel({ serviceSlug }: { serviceSlug: string }) {
  const { t } = useLanguage();
  const { data, isPending, isError } = useQuery({
    queryKey: ['campus-service', serviceSlug],
    queryFn: async () => {
      const response = await fetch(`/api/campus/services/${serviceSlug}`);
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.message);
      return payload.data as ServiceInfo;
    },
  });

  if (isPending)
    return <p className="mt-6 text-muted-foreground">{t('正在读取服务状态…', 'Loading service status…')}</p>;
  if (isError)
    return (
      <p className="mt-6 text-muted-foreground">
        {t('暂时无法读取服务状态，请稍后再试。', 'Could not load service status. Please try again later.')}
      </p>
    );

  const emptyText =
    serviceSlug === 'network-usage' || serviceSlug === 'online-devices'
      ? t(
          data.emptyText,
          'Sign in to the university campus network service to view your usage summary and connected devices. Your password is used only for this request.',
        )
      : data.emptyText;

  return (
    <section className="mt-6 rounded-lg border border-border bg-card p-5">
      <span className="rounded-full bg-secondary px-3 py-1 text-xs text-muted-foreground">
        {data.status === 'available' ? t('已接入', 'Available') : t('待接入', 'Pending')}
      </span>
      <p className="mt-4 leading-7 text-muted-foreground">{emptyText}</p>
      {data.slug === 'network-usage' || data.slug === 'online-devices' || data.slug === 'dorm-water' ? (
        <CampusAuthPanels serviceSlug={data.slug} authReady={data.authReady} />
      ) : (
        <p className="mt-3 text-sm text-muted-foreground">
          {data.authReady
            ? t('已关联学校身份。', 'Your university identity is linked.')
            : t(
                '登录学校统一身份认证后，可建立学校身份映射。',
                'Sign in with Xidian IDS to link your university identity.',
              )}
          {data.requiredAccess.length > 0 &&
            ` ${t('接入还需要：', 'Required access: ')}${data.requiredAccess
              .map((access) =>
                t(
                  access,
                  access === '本人校园网账号、密码和图形验证码'
                    ? 'Your campus network account, password, and captcha'
                    : access,
                ),
              )
              .join(', ')}.`}
        </p>
      )}
    </section>
  );
}
