import { DiscoverFilters } from '@/components/DiscoverFilters';
import { DiscoverProfiles } from '@/components/DiscoverProfiles';
import { DiscoverSearch } from '@/components/DiscoverSearch';
import { PageHeader } from '@/components/ui/PageHeader';

export const metadata = {
  title: '探索 | 西电知行',
};

export default async function Discover() {
  return (
    <div>
      <PageHeader title="探索" sticky />
      <div className="px-4 pt-4 sm:px-5">
        <DiscoverSearch />
        <DiscoverFilters />
        <DiscoverProfiles />
      </div>
    </div>
  );
}
