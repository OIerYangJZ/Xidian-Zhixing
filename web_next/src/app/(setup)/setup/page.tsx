import { EditProfileForm } from '@/components/EditProfileForm';
import { ResponsiveContainer } from '@/components/ui/ResponsiveContainer';
import { PageHeader } from '@/components/ui/PageHeader';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';

export async function generateMetadata() {
  const language = await getInterfaceLanguage();
  return { title: language === 'en' ? 'Complete your profile | Xidian Zhixing' : '完善资料 | 西电知行' };
}

export default async function Page() {
  const language = await getInterfaceLanguage();
  return (
    <div>
      <PageHeader title={language === 'en' ? 'Welcome to Zhixing' : '欢迎加入知行'} sticky />
      <ResponsiveContainer className="px-4 py-5 md:px-5">
        <EditProfileForm redirectTo="/feed" />
      </ResponsiveContainer>
    </div>
  );
}
