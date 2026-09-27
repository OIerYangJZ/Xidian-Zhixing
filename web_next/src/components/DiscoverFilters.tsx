'use client';

import { useLanguage } from '@/hooks/useLanguage';

export function DiscoverFilters() {
  const { t } = useLanguage();
  return (
    <p className="mb-6 mt-3 text-sm text-muted-foreground">
      {t('按校园社区和话题发现同学。', 'Find people across campus communities and topics.')}
    </p>
  );
}
