import { getProfile } from '../../getProfile';
import { About } from './About';

export async function generateMetadata({ params }: { params: { username: string } }) {
  const profile = await getProfile(params.username);
  return {
    title: `简介 | ${profile?.name || '西电知行'}`,
  };
}

export default async function Page({ params }: { params: { username: string } }) {
  const profile = await getProfile(params.username);
  if (!profile) return null;

  return (
    <div className="mt-1">
      <About profile={profile} />
    </div>
  );
}
