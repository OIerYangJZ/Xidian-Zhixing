import { Posts } from '@/components/Posts';
import { getServerUser } from '@/lib/getServerUser';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { getProfile } from '../../getProfile';

export async function generateMetadata({ params }: { params: { username: string } }) {
  const profile = await getProfile(params.username);
  return {
    title:
      getInterfaceLanguage() === 'en'
        ? `Bookmarks | ${profile?.name || 'Zhixing'}`
        : `收藏 | ${profile?.name || '西电知行'}`,
  };
}

export default async function BookmarksPage({ params }: { params: { username: string } }) {
  const [user] = await getServerUser();
  const profile = await getProfile(params.username);
  if (!profile || user?.id !== profile.id) return null;

  return <Posts type="bookmarks" userId={user.id} />;
}
