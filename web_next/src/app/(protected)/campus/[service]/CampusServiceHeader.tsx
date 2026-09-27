'use client';

import Link from 'next/link';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';

const serviceTitles: Record<string, [string, string]> = {
  'network-usage': ['校园网用量', 'Campus network usage'],
  'online-devices': ['在线设备', 'Online devices'],
  'dorm-water': ['宿舍水机', 'Dorm water service'],
};

export function CampusServiceHeader({ slug, title }: { slug: string; title: string }) {
  const { t } = useLanguage();
  const [chinese, english] = serviceTitles[slug] || [title, title];

  return (
    <PageHeader
      title={t(chinese, english)}
      action={
        <Link href="/campus" className="rounded-full px-3 py-2 text-sm text-primary transition hover:bg-primary/10">
          {t('返回', 'Back')}
        </Link>
      }
      sticky
    />
  );
}
