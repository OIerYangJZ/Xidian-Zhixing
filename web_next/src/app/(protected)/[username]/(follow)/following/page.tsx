import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { ProfileFollowList } from '../ProfileFollowList';
import { getProfile } from '../../getProfile';

export async function generateMetadata(props: { params: Promise<{ username: string }> }) {
  const params = await props.params;
  const profile = await getProfile(params.username);
  return {
    title:
      (await getInterfaceLanguage()) === 'en'
        ? `Following | ${profile?.name || 'Zhixing'}`
        : `关注 | ${profile?.name || '西电知行'}`,
  };
}

export default async function Page(props: { params: Promise<{ username: string }> }) {
  const params = await props.params;
  const profile = await getProfile(params.username);

  return <ProfileFollowList profileId={profile?.id} mode="following" />;
}
