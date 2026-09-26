import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

export async function POST(request: Request, { params }: { params: { userId: string } }) {
  const [user] = await getServerUser();
  if (!user || params.userId !== user.id) return NextResponse.json({}, { status: 401 });

  const { postId } = await request.json();
  const existing = await prisma.bookmark.findUnique({
    where: { userId_postId: { userId: user.id, postId: Number(postId) } },
  });
  if (existing) return NextResponse.json({}, { status: 409 });

  await prisma.bookmark.create({ data: { userId: user.id, postId: Number(postId) } });
  return NextResponse.json({});
}
