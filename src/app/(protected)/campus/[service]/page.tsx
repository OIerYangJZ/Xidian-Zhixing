import { notFound } from 'next/navigation';
import { getCampusServices } from '@/lib/campus/catalog';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { CampusDataPanel } from './CampusDataPanel';
import { CampusServiceHeader } from './CampusServiceHeader';

export async function generateMetadata(props: { params: Promise<{ service: string }> }) {
  const params = await props.params;
  const service = getCampusServices(false).find(({ slug }) => slug === params.service);
  if ((await getInterfaceLanguage()) === 'en') {
    const title =
      service?.slug === 'network-usage'
        ? 'Campus network usage'
        : service?.slug === 'online-devices'
        ? 'Online devices'
        : service?.name || 'Campus services';
    return { title: `${title} | Xidian Zhixing` };
  }
  return { title: service ? `${service.name} | 西电知行` : '校园服务 | 西电知行' };
}

export default async function CampusServicePage(props: { params: Promise<{ service: string }> }) {
  const params = await props.params;
  const service = getCampusServices(false).find(({ slug }) => slug === params.service);
  if (!service) notFound();

  return (
    <main>
      <CampusServiceHeader slug={service.slug} title={service.name} />
      <div className="px-4 py-5 sm:px-5">
        <CampusDataPanel serviceSlug={service.slug} />
      </div>
    </main>
  );
}
