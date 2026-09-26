import { getPostsSorter } from '@/hooks/usePostsSorter';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { selectPost } from '@/lib/prisma/selectPost';
import { toGetPost } from '@/lib/prisma/toGetPost';
import { GetPost } from '@/types/definitions';
import { NextResponse } from 'next/server';

export async function GET(request: Request, { params }: { params: { userId: string } }) {
  const [user] = await getServerUser();
  if (!user || params.userId !== user.id) return NextResponse.json({}, { status: 401 });
  const { filters, limitAndOrderBy } = getPostsSorter(request.url);
  const savedPosts = await prisma.post.findMany({
    where: {
      bookmarks: { some: { userId: user.id } },
      status: 'PUBLISHED',
      moderationCases: { none: { status: 'OPEN' } },
      ...filters,
    },
    ...limitAndOrderBy,
    select: selectPost(user.id),
  });
  const posts: GetPost[] = await Promise.all(savedPosts.map((post) => toGetPost(post, user.id)));
  return NextResponse.json(posts);
}
