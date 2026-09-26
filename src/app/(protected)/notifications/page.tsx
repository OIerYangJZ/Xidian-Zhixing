import { getServerUser } from '@/lib/getServerUser';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { Notifications } from './Notifications';

export async function generateMetadata() {
  return { title: (await getInterfaceLanguage()) === 'en' ? 'Notifications | Xidian Zhixing' : '通知 | 西电知行' };
}

export default async function Page() {
  const [user] = await getServerUser();

  if (!user) return null;
  return (
    <div>
      <Notifications userId={user.id} />
    </div>
  );
}
