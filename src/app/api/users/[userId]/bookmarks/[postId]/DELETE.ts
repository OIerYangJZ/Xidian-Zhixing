import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

export async function DELETE(_request: Request, { params }: { params: { userId: string; postId: string } }) {
  const [user] = await getServerUser();
  if (!user || params.userId !== user.id) return NextResponse.json({}, { status: 401 });

  const postId = Number(params.postId);
  const existing = await prisma.bookmark.findUnique({
    where: { userId_postId: { userId: user.id, postId } },
  });
  if (!existing) return NextResponse.json({}, { status: 409 });

  await prisma.bookmark.delete({ where: { userId_postId: { userId: user.id, postId } } });
  return NextResponse.json({});
}
