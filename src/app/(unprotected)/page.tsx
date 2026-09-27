import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { getServerUser } from '@/lib/getServerUser';
import { redirect } from 'next/navigation';

export const metadata = {
  title: '西电知行 · Xidian University',
  description: '西电知行：连接西安电子科技大学的学习、研究与校园生活。',
};

export default async function Page() {
  const [user] = await getServerUser();
  if (user) redirect('/feed');

  const language = await getInterfaceLanguage();
  return (
    <iframe
      title={language === 'en' ? 'Xidian Zhixing home' : '西电知行首页'}
      src={`/zhixing-home/index.html?lang=${language}`}
      className="fixed inset-0 z-50 h-dvh w-full border-0 bg-white"
    />
  );
}
