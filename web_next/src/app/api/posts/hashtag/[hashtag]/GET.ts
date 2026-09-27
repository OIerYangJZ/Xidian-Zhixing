/**
 * GET /api/posts/hashtag/:hashtag
 * - Returns the posts that contains the specified `hashtag`.
 */
import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma/prisma';
import { selectPost } from '@/lib/prisma/selectPost';
import { GetPost } from '@/types/definitions';
import { toGetPost } from '@/lib/prisma/toGetPost';
import { getServerUser } from '@/lib/getServerUser';
import { getPostsSorter } from '@/hooks/usePostsSorter';

export async function GET(request: Request, props: { params: Promise<{ hashtag: string }> }) {
  const params = await props.params;
  /**
   * The [user] will only be used to check whether the
   * user requesting the Posts have like them or not.
   */
  const [user] = await getServerUser();
  const { filters, limitAndOrderBy } = getPostsSorter(request.url);

  const res = await prisma.post.findMany({
    where: {
      status: 'PUBLISHED',
      moderationCases: { none: { status: 'OPEN' } },
      content: {
        search: decodeURIComponent(params.hashtag),
      },
      ...filters,
    },
    ...limitAndOrderBy,
    select: selectPost(user?.id),
  });

  const postsPromises = res.map((post) => toGetPost(post, user?.id));
  const posts = await Promise.all(postsPromises);

  return NextResponse.json<GetPost[] | null>(posts);
}
