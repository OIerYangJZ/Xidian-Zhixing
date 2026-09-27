import { LegalDocumentView } from '@/components/LegalDocumentView';
import { PRIVACY_POLICY } from '@/lib/legal';

export const metadata = { title: '隐私政策 | 西电知行' };

export default function Page() {
  return <LegalDocumentView document={PRIVACY_POLICY} />;
}
