'use client';

import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';

export function DiscoverPageHeader() {
  const { t } = useLanguage();
  return <PageHeader title={t('探索', 'Explore')} sticky />;
}
