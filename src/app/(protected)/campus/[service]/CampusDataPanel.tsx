'use client';

import { useQuery } from '@tanstack/react-query';
import { CampusAuthPanels } from './CampusAuthPanels';

type ServiceInfo = {
  status: 'pending' | 'available';
  authReady: boolean;
  emptyText: string;
  requiredAccess: string[];
  slug: string;
};

export function CampusDataPanel({ serviceSlug }: { serviceSlug: string }) {
  const { data, isPending, isError } = useQuery({
    queryKey: ['campus-service', serviceSlug],
    queryFn: async () => {
      const response = await fetch(`/api/campus/services/${serviceSlug}`);
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.message);
      return payload.data as ServiceInfo;
    },
  });

  if (isPending) return <p className="mt-6 text-muted-foreground">正在读取服务状态…</p>;
  if (isError) return <p className="mt-6 text-muted-foreground">暂时无法读取服务状态，请稍后再试。</p>;

  return (
    <section className="mt-6 rounded-lg border border-border bg-card p-5">
      <span className="rounded-full bg-secondary px-3 py-1 text-xs text-muted-foreground">
        {data.status === 'available' ? '已接入' : '待接入'}
      </span>
      <p className="mt-4 leading-7 text-muted-foreground">{data.emptyText}</p>
      {data.slug === 'network-usage' || data.slug === 'online-devices' || data.slug === 'dorm-water' ? (
        <CampusAuthPanels serviceSlug={data.slug} authReady={data.authReady} />
      ) : (
        <p className="mt-3 text-sm text-muted-foreground">
          {data.authReady ? '已关联学校身份。' : '登录学校统一身份认证后，可建立学校身份映射。'}
          {data.requiredAccess.length > 0 && ` 接入还需要：${data.requiredAccess.join('、')}。`}
        </p>
      )}
    </section>
  );
}
