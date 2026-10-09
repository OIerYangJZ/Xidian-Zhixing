import { NextResponse } from 'next/server';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';

export async function GET(_request: Request, props: { params: Promise<{ userId: string }> }) {
  const { userId } = await props.params;
  const [user] = await getServerUser();
  if (!user?.id || user.id !== userId) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const comments = await prisma.comment.findMany({
    where: { userId },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: 100,
    select: {
      id: true,
      content: true,
      createdAt: true,
      postId: true,
      parentId: true,
      post: { select: { content: true } },
    },
  });

  return NextResponse.json(
    comments.map(({ post, ...comment }) => ({
      ...comment,
      postTitle: (post.content || '').split('\n')[0].slice(0, 80) || '原帖',
    })),
  );
}
