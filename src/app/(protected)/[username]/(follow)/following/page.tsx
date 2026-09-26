import { DiscoverProfiles } from '@/components/DiscoverProfiles';
import { DiscoverSearch } from '@/components/DiscoverSearch';
import { PageHeader } from '@/components/ui/PageHeader';
import { getProfile } from '../../getProfile';

export async function generateMetadata({ params }: { params: { username: string } }) {
  const profile = await getProfile(params.username);
  return {
    title: `关注 | ${profile?.name || '西电知行'}`,
  };
}

export default async function Page({ params }: { params: { username: string } }) {
  const profile = await getProfile(params.username);

  return (
    <div>
      <PageHeader title="关注" sticky />
      <div className="pt-4">
        <div className="px-4 sm:px-5">
          <DiscoverSearch label="搜索关注" />
        </div>
        <DiscoverProfiles followingOf={profile?.id} />
      </div>
    </div>
  );
}
