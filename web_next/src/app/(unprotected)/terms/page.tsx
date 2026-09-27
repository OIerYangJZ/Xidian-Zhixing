import { LegalDocumentView } from '@/components/LegalDocumentView';
import { TERMS_OF_SERVICE } from '@/lib/legal';

export const metadata = { title: '用户协议 | 西电知行' };

export default function Page() {
  return <LegalDocumentView document={TERMS_OF_SERVICE} />;
}
