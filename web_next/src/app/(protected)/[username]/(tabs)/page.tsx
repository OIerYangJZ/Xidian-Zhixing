import { Posts } from '@/components/Posts';
import { CreatePostModalLauncher } from '@/components/CreatePostModalLauncher';
import { getServerUser } from '@/lib/getServerUser';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { getProfile } from '../getProfile';

export async function generateMetadata(props: { params: Promise<{ username: string }> }) {
  const params = await props.params;
  const profile = await getProfile(params.username);
  return {
    title: profile?.name || ((await getInterfaceLanguage()) === 'en' ? 'Xidian Zhixing' : '西电知行'),
  };
}

export default async function Page(props: { params: Promise<{ username: string }> }) {
  const params = await props.params;
  const [user] = await getServerUser();
  const profile = await getProfile(params.username);
  const shouldShowCreatePost = user?.id === profile?.id;

  return (
    <div>
      {shouldShowCreatePost && (
        <div className="mt-4">
          <CreatePostModalLauncher />
        </div>
      )}
      {profile && <Posts type="profile" userId={profile.id} />}
    </div>
  );
}
