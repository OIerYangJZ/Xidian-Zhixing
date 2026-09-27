import { PageHeader } from '@/components/ui/PageHeader';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { BlockedUsersManager } from '../BlockedUsersManager';

export async function generateMetadata() {
  return {
    title: (await getInterfaceLanguage()) === 'en' ? 'Blocked accounts | Xidian Zhixing' : '屏蔽账号 | 西电知行',
  };
}

export default async function BlockedUsersSettingsPage() {
  const title = (await getInterfaceLanguage()) === 'en' ? 'Blocked accounts' : '屏蔽账号';
  return (
    <div>
      <PageHeader title={title} sticky />
      <BlockedUsersManager />
    </div>
  );
}
