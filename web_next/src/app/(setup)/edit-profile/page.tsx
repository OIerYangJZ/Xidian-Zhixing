'use client';

import { EditProfileForm } from '@/components/EditProfileForm';
import { ResponsiveContainer } from '@/components/ui/ResponsiveContainer';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';

export default function Page() {
  const { t } = useLanguage();
  return (
    <div>
      <PageHeader title={t('编辑资料', 'Edit profile')} sticky />
      <ResponsiveContainer className="px-4 py-5 md:px-5">
        <EditProfileForm />
      </ResponsiveContainer>
    </div>
  );
}
