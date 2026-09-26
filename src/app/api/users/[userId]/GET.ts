import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma/prisma';
import { FindUserResult, GetUser } from '@/types/definitions';
import { includeToUser } from '@/lib/prisma/includeToUser';
import { toGetUser } from '@/lib/prisma/toGetUser';
import { getServerUser } from '@/lib/getServerUser';

export async function GET(request: Request, props: { params: Promise<{ userId: string }> }) {
  const params = await props.params;
  // The user is only for checking whether the requestee
  // is following the user being rquested.
  const [user] = await getServerUser();

  const { userId } = params;
  if (user && user.id !== userId) {
    const block = await prisma.userBlock.findFirst({
      where: {
        OR: [
          { blockerId: user.id, blockedId: userId },
          { blockerId: userId, blockedId: user.id },
        ],
      },
      select: { id: true },
    });
    if (block) return NextResponse.json(null);
  }
  const res: FindUserResult | null = await prisma.user.findFirst({
    where: {
      id: userId,
    },
    include: includeToUser(user?.id),
  });

  if (res === null) {
    return NextResponse.json(null);
  }

  const userResponse = toGetUser(res);
  return NextResponse.json<GetUser | null>(userResponse);
}
