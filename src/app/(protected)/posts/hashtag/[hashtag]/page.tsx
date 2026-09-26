import { Posts } from '@/components/Posts';
import { PageHeader } from '@/components/ui/PageHeader';

export default async function Page(props: { params: Promise<{ hashtag: string }> }) {
  const params = await props.params;
  return (
    <div>
      <PageHeader title={`#${params.hashtag}`} sticky />
      <Posts type="hashtag" hashtag={params.hashtag} />
    </div>
  );
}
