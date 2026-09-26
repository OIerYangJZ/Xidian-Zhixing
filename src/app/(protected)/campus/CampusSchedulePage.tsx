'use client';

import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';
import { CampusScheduleView } from './CampusScheduleView';

export function CampusSchedulePage({ mode }: { mode: 'today' | 'calendar' }) {
  const { t } = useLanguage();

  return (
    <main>
      <PageHeader title={mode === 'today' ? t('今日校园', 'Today') : t('校园日历', 'Campus calendar')} sticky />
      <div className="px-4 sm:px-5">
        <CampusScheduleView mode={mode} />
      </div>
    </main>
  );
}
