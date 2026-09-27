import { Posts } from '@/components/Posts';
import { getServerUser } from '@/lib/getServerUser';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { getProfile } from '../../getProfile';

export async function generateMetadata(props: { params: Promise<{ username: string }> }) {
  const params = await props.params;
  const profile = await getProfile(params.username);
  return {
    title:
      (await getInterfaceLanguage()) === 'en'
        ? `Bookmarks | ${profile?.name || 'Zhixing'}`
        : `收藏 | ${profile?.name || '西电知行'}`,
  };
}

export default async function BookmarksPage(props: { params: Promise<{ username: string }> }) {
  const params = await props.params;
  const [user] = await getServerUser();
  const profile = await getProfile(params.username);
  if (!profile || user?.id !== profile.id) return null;

  return <Posts type="bookmarks" userId={user.id} />;
}
