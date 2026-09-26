import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

export async function POST(request: Request, { params }: { params: { userId: string } }) {
  const [user] = await getServerUser();
  if (!user || user.id !== params.userId) return NextResponse.json({ error: 'Unauthorized.' }, { status: 401 });
  const { postId } = (await request.json()) as { postId: number };
  await prisma.repost.create({ data: { userId: user.id, postId: Number(postId) } });
  return NextResponse.json({ reposted: true });
}
