import { Posts } from '@/components/Posts';
import { PageHeader } from '@/components/ui/PageHeader';

export default function Page({ params }: { params: { hashtag: string } }) {
  return (
    <div>
      <PageHeader title={`#${params.hashtag}`} sticky />
      <Posts type="hashtag" hashtag={params.hashtag} />
    </div>
  );
}
