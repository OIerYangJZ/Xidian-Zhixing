import { notFound } from 'next/navigation';
import { PageHeader } from '@/components/ui/PageHeader';
import { getKnowledgeAdmin } from '@/lib/ai/admin';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { ModerationQueue } from './ModerationQueue';

export async function generateMetadata() {
  return { title: (await getInterfaceLanguage()) === 'en' ? 'Moderation | Xidian Zhixing' : '内容审核 | 西电知行' };
}

export default async function ModerationPage() {
  if (!(await getKnowledgeAdmin())) notFound();

  return (
    <main>
      <PageHeader title="内容审核" />
      <ModerationQueue />
    </main>
  );
}
