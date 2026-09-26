import { notFound } from 'next/navigation';
import { PageHeader } from '@/components/ui/PageHeader';
import { getKnowledgeAdmin } from '@/lib/ai/admin';
import { ModerationQueue } from './ModerationQueue';

export const metadata = { title: '内容审核 | 西电知行' };

export default async function ModerationPage() {
  if (!(await getKnowledgeAdmin())) notFound();

  return (
    <main>
      <PageHeader title="内容审核" />
      <ModerationQueue />
    </main>
  );
}
