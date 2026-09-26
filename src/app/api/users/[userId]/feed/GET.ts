/**
 * GET /api/users/:userId/feed
 * - Allows an authenticated user to retrieve the most recent posts
 * posted by the user and their followed users.
 */

import { getPostsSorter } from '@/hooks/usePostsSorter';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { selectPost } from '@/lib/prisma/selectPost';
import { toGetPost } from '@/lib/prisma/toGetPost';
import { NextResponse } from 'next/server';
import { GetPost } from '@/types/definitions';

export async function GET(request: Request, props: { params: Promise<{ userId: string }> }) {
  const params = await props.params;
  const { filters, limitAndOrderBy } = getPostsSorter(request.url);

  const [user] = await getServerUser();
  if (!user || params.userId !== user.id) return NextResponse.json({}, { status: 401 });

  // Get the IDs of the user's followed users
  const following = await prisma.follow.findMany({
    where: {
      followerId: user.id,
    },
    select: {
      followingId: true,
    },
  });
  const followingIds = following.map((u) => u.followingId);

  const res = await prisma.post.findMany({
    where: {
      userId: {
        in: [...followingIds, user.id],
      },
      status: 'PUBLISHED',
      moderationCases: { none: { status: 'OPEN' } },
      NOT: [
        { user: { blocksMade: { some: { blockedId: user.id } } } },
        { user: { blocksReceived: { some: { blockerId: user.id } } } },
      ],
      ...filters,
    },
    ...limitAndOrderBy,
    select: selectPost(user.id),
  });

  const postsPromises = res.map((post) => toGetPost(post, user.id));
  const posts = await Promise.all(postsPromises);

  return NextResponse.json<GetPost[]>(posts);
}
