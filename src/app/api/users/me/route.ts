import { getServerUser } from '@/lib/getServerUser';
import { includeToUser } from '@/lib/prisma/includeToUser';
import prisma from '@/lib/prisma/prisma';
import { toGetUser } from '@/lib/prisma/toGetUser';
import { NextResponse } from 'next/server';

export async function GET() {
  const [user] = await getServerUser();
  if (!user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const account = await prisma.user.findUnique({
    where: { id: user.id },
    include: includeToUser(user.id),
  });
  if (!account) return NextResponse.json({ error: 'not_found' }, { status: 404 });
  return NextResponse.json(toGetUser(account));
}
