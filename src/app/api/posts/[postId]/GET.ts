/**
 * GET /api/posts/:postId
 * - Returns the data of a specific post.
 */

import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { selectPost } from '@/lib/prisma/selectPost';
import { toGetPost } from '@/lib/prisma/toGetPost';
import { NextResponse } from 'next/server';
import { GetPost } from '@/types/definitions';

export async function GET(request: Request, props: { params: Promise<{ postId: string }> }) {
  const params = await props.params;
  /**
   * The [user] will only be used to check whether the
   * user requesting the Post has like it or not.
   */
  const [user] = await getServerUser();
  const res = await prisma.post.findUnique({
    where: {
      id: parseInt(params.postId, 10),
      OR: [
        { status: 'PUBLISHED', moderationCases: { none: { status: 'OPEN' } } },
        ...(user?.id ? [{ userId: user.id }] : []),
      ],
      ...(user?.id && {
        NOT: [
          { user: { blocksMade: { some: { blockedId: user.id } } } },
          { user: { blocksReceived: { some: { blockerId: user.id } } } },
        ],
      }),
    },
    select: selectPost(user?.id),
  });

  if (res === null) return NextResponse.json(null);
  return NextResponse.json<GetPost>(await toGetPost(res, user?.id));
}

export async function POST(_request: Request, props: { params: Promise<{ postId: string }> }) {
  const params = await props.params;
  const postId = Number.parseInt(params.postId, 10);
  if (!Number.isInteger(postId)) return NextResponse.json({ error: 'Invalid post id.' }, { status: 400 });
  const post = await prisma.post.update({
    where: { id: postId },
    data: { viewCount: { increment: 1 } },
    select: { viewCount: true },
  });
  return NextResponse.json(post);
}
