import { Posts } from '@/components/Posts';
import { PageHeader } from '@/components/ui/PageHeader';

export default async function Page(props: { params: Promise<{ hashtag: string }> }) {
  const params = await props.params;
  const hashtag = decodeURIComponent(params.hashtag);
  return (
    <div>
      <PageHeader title={`#${hashtag}`} sticky />
      <Posts type="hashtag" hashtag={hashtag} />
    </div>
  );
}
