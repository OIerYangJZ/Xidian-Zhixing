import { CreatePostModalLauncher } from '@/components/CreatePostModalLauncher';
import { Posts } from '@/components/Posts';

export const metadata = { title: '西电知行 · 首页' };

export default function Page() {
  return (
    <div className="min-h-[calc(100dvh-3.5rem)]">
      <CreatePostModalLauncher />
      <Posts type="feed" />
    </div>
  );
}
