import { PageHeader } from '@/components/ui/PageHeader';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { BlockedUsersManager } from '../BlockedUsersManager';

export function generateMetadata() {
  return { title: getInterfaceLanguage() === 'en' ? 'Blocked accounts | Xidian Zhixing' : '屏蔽账号 | 西电知行' };
}

export default function BlockedUsersSettingsPage() {
  const title = getInterfaceLanguage() === 'en' ? 'Blocked accounts' : '屏蔽账号';
  return (
    <div>
      <PageHeader title={title} sticky />
      <BlockedUsersManager />
    </div>
  );
}
