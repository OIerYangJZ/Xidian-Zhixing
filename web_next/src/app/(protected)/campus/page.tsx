'use client';

import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import { campusQuickLinks, toCampusService } from '@/lib/campus/catalog';
import { listCampusServices } from '@/lib/backend/endpoints';
import { GenericLoading } from '@/components/GenericLoading';
import { useLanguage } from '@/hooks/useLanguage';
import { CampusDirectory } from './CampusDirectory';

export default function CampusPage() {
  const { t } = useLanguage();
  const { data, isPending } = useQuery({
    queryKey: ['campus', 'services'],
    queryFn: listCampusServices,
    staleTime: 300000,
  });
  const groups = useMemo(() => {
    const services = (data ?? []).filter((service) => service.enabled).map(toCampusService);
    return Array.from(new Set(services.map((service) => service.groupName))).map((title) => ({
      title,
      services: services.filter((service) => service.groupName === title),
    }));
  }, [data]);

  if (isPending) return <GenericLoading>{t('正在加载校园服务', 'Loading campus services')}</GenericLoading>;
  return <CampusDirectory quickLinks={campusQuickLinks} groups={groups} />;
}
