import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

export async function DELETE(_request: Request, props: { params: Promise<{ userId: string; postId: string }> }) {
  const params = await props.params;
  const [user] = await getServerUser();
  if (!user || user.id !== params.userId) return NextResponse.json({ error: 'Unauthorized.' }, { status: 401 });
  await prisma.repost.deleteMany({ where: { userId: user.id, postId: Number(params.postId) } });
  return NextResponse.json({ reposted: false });
}
