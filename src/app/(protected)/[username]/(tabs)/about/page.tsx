import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { getProfile } from '../../getProfile';
import { About } from './About';

export async function generateMetadata(props: { params: Promise<{ username: string }> }) {
  const params = await props.params;
  const profile = await getProfile(params.username);
  return {
    title:
      (await getInterfaceLanguage()) === 'en'
        ? `About | ${profile?.name || 'Zhixing'}`
        : `简介 | ${profile?.name || '西电知行'}`,
  };
}

export default async function Page(props: { params: Promise<{ username: string }> }) {
  const params = await props.params;
  const profile = await getProfile(params.username);
  if (!profile) return null;

  return (
    <div className="mt-1">
      <About profile={profile} />
    </div>
  );
}
