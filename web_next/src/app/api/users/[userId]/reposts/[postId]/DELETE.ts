import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

export async function DELETE(_request: Request, props: { params: Promise<{ userId: string; postId: string }> }) {
  const params = await props.params;
  const [user] = await getServerUser();
  if (!user || user.id !== params.userId) return NextResponse.json({ error: 'Unauthorized.' }, { status: 401 });
  const postId = Number(params.postId);
  if (!Number.isSafeInteger(postId) || postId < 1) {
    return NextResponse.json({ error: 'Invalid post.' }, { status: 400 });
  }
  await prisma.repost.deleteMany({ where: { userId: user.id, postId } });
  return NextResponse.json({ reposted: false });
}
