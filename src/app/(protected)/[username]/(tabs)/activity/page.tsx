import { getServerUser } from '@/lib/getServerUser';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { getProfile } from '../../getProfile';
import { Activities } from './Activities';
import { ActivityAccessMessage } from './ActivityAccessMessage';

export async function generateMetadata({ params }: { params: { username: string } }) {
  const profile = await getProfile(params.username);
  return {
    title:
      getInterfaceLanguage() === 'en'
        ? `Activity | ${profile?.name || 'Xidian Zhixing'}`
        : `互动 | ${profile?.name || '西电知行'}`,
  };
}

export default async function Page({ params }: { params: { username: string } }) {
  const [user] = await getServerUser();
  if (!user) return <ActivityAccessMessage reason="signin" />;
  const profile = await getProfile(params.username);
  const isOwn = user?.id === profile?.id;

  if (!isOwn) return <ActivityAccessMessage reason="private" />;
  return (
    <div className="mt-4">
      <Activities userId={user.id} />
    </div>
  );
}
