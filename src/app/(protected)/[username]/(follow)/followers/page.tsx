import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { ProfileFollowList } from '../ProfileFollowList';
import { getProfile } from '../../getProfile';

export async function generateMetadata({ params }: { params: { username: string } }) {
  const profile = await getProfile(params.username);
  return {
    title:
      getInterfaceLanguage() === 'en'
        ? `Followers | ${profile?.name || 'Zhixing'}`
        : `粉丝 | ${profile?.name || '西电知行'}`,
  };
}

export default async function Page({ params }: { params: { username: string } }) {
  const profile = await getProfile(params.username);

  return <ProfileFollowList profileId={profile?.id} mode="followers" />;
}
