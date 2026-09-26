/**
 * GET /api/posts/:postId/comments
 * - Returns the comments of a post specified by the postId provided.
 */
import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma/prisma';
import { FindCommentResult, GetComment } from '@/types/definitions';
import { getServerUser } from '@/lib/getServerUser';
import { includeToComment } from '@/lib/prisma/includeToComment';
import { toGetComment } from '@/lib/prisma/toGetComment';

export async function GET(request: Request, { params }: { params: { postId: string } }) {
  /**
   * The `userId` will only be used to check whether the user
   * requesting the comments has liked them or not.
   */
  const [user] = await getServerUser();
  const userId = user?.id;
  const sort = new URL(request.url).searchParams.get('sort') === 'time' ? 'time' : 'hot';

  const res: FindCommentResult[] = await prisma.comment.findMany({
    where: {
      postId: parseInt(params.postId, 10),
      parentId: null,
      post: {
        AND: [
          { OR: [{ status: 'PUBLISHED' }, { userId }] },
          ...(user
            ? [
                {
                  user: {
                    blocksMade: { none: { blockedId: user.id } },
                    blocksReceived: { none: { blockerId: user.id } },
                  },
                },
              ]
            : []),
        ],
      },
      moderationCases: { none: { status: 'OPEN' } },
    },
    include: includeToComment(userId),
    orderBy: { id: 'desc' },
  });

  const commentsPromises = res.map(toGetComment);
  const comments = await Promise.all(commentsPromises);
  if (sort === 'hot') {
    comments.sort(
      (a, b) =>
        b._count.commentLikes - a._count.commentLikes ||
        b._count.replies - a._count.replies ||
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
    );
  }

  return NextResponse.json<GetComment[]>(comments);
}
