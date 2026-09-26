import { getServerUser } from '@/lib/getServerUser';
import { Notifications } from './Notifications';

export const metadata = {
  title: '通知 | 西电知行',
};

export default async function Page() {
  const [user] = await getServerUser();

  if (!user) return null;
  return (
    <div>
      <Notifications userId={user.id} />
    </div>
  );
}
