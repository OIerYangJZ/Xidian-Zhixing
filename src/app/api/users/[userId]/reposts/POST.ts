import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

export async function POST(request: Request, { params }: { params: { userId: string } }) {
  const [user] = await getServerUser();
  if (!user || user.id !== params.userId) return NextResponse.json({ error: 'Unauthorized.' }, { status: 401 });
  const { postId } = (await request.json()) as { postId: number };
  await prisma.repost.upsert({
    where: { userId_postId: { userId: user.id, postId: Number(postId) } },
    create: { userId: user.id, postId: Number(postId) },
    update: {},
  });
  return NextResponse.json({ reposted: true });
}
