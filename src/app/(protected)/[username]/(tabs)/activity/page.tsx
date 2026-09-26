import { getServerUser } from '@/lib/getServerUser';
import { getProfile } from '../../getProfile';
import { Activities } from './Activities';

export async function generateMetadata({ params }: { params: { username: string } }) {
  const profile = await getProfile(params.username);
  return {
    title: `互动 | ${profile?.name || '西电知行'}`,
  };
}

export default async function Page({ params }: { params: { username: string } }) {
  const [user] = await getServerUser();
  if (!user) return <p className="px-4 py-6 text-sm text-muted-foreground">请先登录以查看互动。</p>;
  const profile = await getProfile(params.username);
  const isOwn = user?.id === profile?.id;

  if (!isOwn) return <p className="px-4 py-6 text-sm text-muted-foreground">你没有权限查看此页面。</p>;
  return (
    <div className="mt-4">
      <Activities userId={user.id} />
    </div>
  );
}
