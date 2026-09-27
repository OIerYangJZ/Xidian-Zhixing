import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

export async function POST(request: Request, props: { params: Promise<{ userId: string }> }) {
  const params = await props.params;
  const [user] = await getServerUser();
  if (!user || user.id !== params.userId) return NextResponse.json({ error: 'Unauthorized.' }, { status: 401 });

  const body = (await request.json().catch(() => null)) as { postId?: unknown } | null;
  if (typeof body?.postId !== 'number' || !Number.isSafeInteger(body.postId) || body.postId < 1) {
    return NextResponse.json({ error: 'Invalid post.' }, { status: 400 });
  }
  const post = await prisma.post.findFirst({
    where: {
      id: body.postId,
      status: 'PUBLISHED',
      moderationCases: { none: { status: 'OPEN' } },
      NOT: [
        { user: { blocksMade: { some: { blockedId: user.id } } } },
        { user: { blocksReceived: { some: { blockerId: user.id } } } },
      ],
    },
    select: { id: true },
  });
  if (!post) return NextResponse.json({ error: 'Post not found.' }, { status: 404 });

  await prisma.repost.upsert({
    where: { userId_postId: { userId: user.id, postId: body.postId } },
    create: { userId: user.id, postId: body.postId },
    update: {},
  });
  return NextResponse.json({ reposted: true });
}
