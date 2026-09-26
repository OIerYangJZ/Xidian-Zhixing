import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

export async function DELETE(_request: Request, { params }: { params: { userId: string; blockedId: string } }) {
  const [user] = await getServerUser();
  if (!user || user.id !== params.userId) return NextResponse.json({ error: 'Unauthorized.' }, { status: 401 });

  const { count } = await prisma.userBlock.deleteMany({
    where: { blockerId: user.id, blockedId: params.blockedId },
  });
  if (!count) return NextResponse.json({ error: 'Block not found.' }, { status: 404 });
  return NextResponse.json({ unblocked: true });
}
