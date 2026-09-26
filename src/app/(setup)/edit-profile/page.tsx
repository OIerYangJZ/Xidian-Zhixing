import { EditProfileForm } from '@/components/EditProfileForm';
import { ResponsiveContainer } from '@/components/ui/ResponsiveContainer';
import { PageHeader } from '@/components/ui/PageHeader';

export const metadata = {
  title: '编辑资料 | 西电知行',
};

export default function Page() {
  return (
    <div>
      <PageHeader title="编辑资料" sticky />
      <ResponsiveContainer className="px-4 py-5 md:px-5">
        <EditProfileForm />
      </ResponsiveContainer>
    </div>
  );
}
