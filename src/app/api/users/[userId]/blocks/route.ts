import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { fileNameToUrl } from '@/lib/s3/fileNameToUrl';
import { Prisma } from '@prisma/client';
import { NextResponse } from 'next/server';
import { z } from 'zod';

const createBlockSchema = z.object({ blockedId: z.string().min(1) });

export async function GET(_request: Request, { params }: { params: { userId: string } }) {
  const [user] = await getServerUser();
  if (!user || user.id !== params.userId) return NextResponse.json({ error: 'Unauthorized.' }, { status: 401 });

  const blocks = await prisma.userBlock.findMany({
    where: { blockerId: user.id },
    orderBy: { createdAt: 'desc' },
    select: {
      createdAt: true,
      blocked: { select: { id: true, username: true, name: true, profilePhoto: true } },
    },
  });
  return NextResponse.json(
    blocks.map(({ createdAt, blocked }) => ({
      ...blocked,
      profilePhoto: fileNameToUrl(blocked.profilePhoto),
      createdAt,
    })),
  );
}

export async function POST(request: Request, { params }: { params: { userId: string } }) {
  const [user] = await getServerUser();
  if (!user || user.id !== params.userId) return NextResponse.json({ error: 'Unauthorized.' }, { status: 401 });

  const parsed = createBlockSchema.safeParse(await request.json());
  if (!parsed.success) return NextResponse.json({ error: 'Invalid blocked user.' }, { status: 422 });
  const { blockedId } = parsed.data;
  if (blockedId === user.id) return NextResponse.json({ error: 'You cannot block your own account.' }, { status: 422 });

  const target = await prisma.user.findUnique({ where: { id: blockedId }, select: { id: true, status: true } });
  if (!target || target.status !== 'ACTIVE') return NextResponse.json({ error: 'User not found.' }, { status: 404 });

  try {
    const existingFollows = await prisma.follow.findMany({
      where: {
        OR: [
          { followerId: user.id, followingId: blockedId },
          { followerId: blockedId, followingId: user.id },
        ],
      },
      select: { id: true },
    });
    await prisma.$transaction([
      prisma.userBlock.create({ data: { blockerId: user.id, blockedId } }),
      prisma.follow.deleteMany({
        where: {
          OR: [
            { followerId: user.id, followingId: blockedId },
            { followerId: blockedId, followingId: user.id },
          ],
        },
      }),
      ...(existingFollows.length
        ? [
            prisma.activity.deleteMany({
              where: {
                type: 'CREATE_FOLLOW',
                OR: [
                  { sourceUserId: user.id, targetUserId: blockedId },
                  { sourceUserId: blockedId, targetUserId: user.id },
                ],
                sourceId: { in: existingFollows.map(({ id }) => id) },
              },
            }),
          ]
        : []),
    ]);
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      return NextResponse.json({ blocked: true });
    }
    throw error;
  }
  return NextResponse.json({ blocked: true }, { status: 201 });
}
