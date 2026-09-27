'use client';

import { useLanguage } from '@/hooks/useLanguage';

export function AllCaughtUp() {
  const { t } = useLanguage();
  return (
    <div className="grid place-items-center px-4 py-7">
      <p className="text-sm text-muted-foreground">{t('暂时没有更多内容', 'You are all caught up')}</p>
    </div>
  );
}
