import { CreatePostModalLauncher } from '@/components/CreatePostModalLauncher';
import { Posts } from '@/components/Posts';
import { getServerUser } from '@/lib/getServerUser';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';

export function generateMetadata() {
  return { title: getInterfaceLanguage() === 'en' ? 'Home | Xidian Zhixing' : '西电知行 · 首页' };
}

export default async function Page() {
  const [user] = await getServerUser();
  return (
    <div className="min-h-[calc(100dvh-3.5rem)]">
      <CreatePostModalLauncher />
      {user && <Posts type="feed" userId={user.id} />}
    </div>
  );
}
