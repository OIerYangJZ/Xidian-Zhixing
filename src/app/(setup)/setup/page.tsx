import { EditProfileForm } from '@/components/EditProfileForm';
import { ResponsiveContainer } from '@/components/ui/ResponsiveContainer';
import { PageHeader } from '@/components/ui/PageHeader';

export const metadata = {
  title: '完善资料 | 西电知行',
};

export default function Page() {
  return (
    <div>
      <PageHeader title="欢迎加入知行" sticky />
      <ResponsiveContainer className="px-4 py-5 md:px-5">
        <EditProfileForm redirectTo="/feed" />
      </ResponsiveContainer>
    </div>
  );
}
