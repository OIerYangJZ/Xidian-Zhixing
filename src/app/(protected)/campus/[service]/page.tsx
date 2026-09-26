import { notFound } from 'next/navigation';
import { getCampusServices } from '@/lib/campus/catalog';
import Link from 'next/link';
import { PageHeader } from '@/components/ui/PageHeader';
import { CampusDataPanel } from './CampusDataPanel';

export function generateMetadata({ params }: { params: { service: string } }) {
  const service = getCampusServices(false).find(({ slug }) => slug === params.service);
  return { title: service ? `${service.name} | 西电知行` : '校园服务 | 西电知行' };
}

export default function CampusServicePage({ params }: { params: { service: string } }) {
  const service = getCampusServices(false).find(({ slug }) => slug === params.service);
  if (!service) notFound();

  return (
    <main>
      <PageHeader
        title={service.name}
        action={
          <Link href="/campus" className="rounded-full px-3 py-2 text-sm text-primary transition hover:bg-primary/10">
            返回
          </Link>
        }
        sticky
      />
      <div className="px-4 py-5 sm:px-5">
        <CampusDataPanel serviceSlug={service.slug} />
      </div>
    </main>
  );
}
