'use client';

import { Suspense } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useQueryParam } from '@/hooks/useQueryParam';
import { useLanguage } from '@/hooks/useLanguage';
import { getCampusService } from '@/lib/backend/endpoints';
import { CampusDataPanel } from './CampusDataPanel';
import { CampusServiceHeader } from './CampusServiceHeader';

function CampusService() {
  const { t } = useLanguage();
  const serviceId = useQueryParam('id');
  const { data: service, isError } = useQuery({
    queryKey: ['campus-service', serviceId],
    queryFn: () => getCampusService(serviceId),
    enabled: !!serviceId,
  });

  if (!serviceId || isError)
    return <p className="px-4 py-6 text-sm text-muted-foreground">{t('没有找到这项服务。', 'Service not found.')}</p>;
  if (!service) return null;

  return (
    <main>
      <CampusServiceHeader slug={service.slug} title={service.name} />
      <div className="px-4 py-5 sm:px-5">
        <CampusDataPanel service={service} />
      </div>
    </main>
  );
}

export default function CampusServicePage() {
  return (
    <Suspense>
      <CampusService />
    </Suspense>
  );
}
