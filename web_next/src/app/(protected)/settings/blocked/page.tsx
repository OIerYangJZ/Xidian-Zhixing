'use client';

import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';
import { BlockedUsersManager } from '../BlockedUsersManager';

export default function BlockedUsersSettingsPage() {
  const { t } = useLanguage();
  return (
    <div>
      <PageHeader title={t('屏蔽账号', 'Blocked accounts')} sticky />
      <BlockedUsersManager />
    </div>
  );
}
