/**
 * GET /api/users/:userId/photos
 * - Returns the visual media URLs of the specified user.
 */

import prisma from '@/lib/prisma/prisma';
import { fileNameToUrl } from '@/lib/s3/fileNameToUrl';
import { NextResponse } from 'next/server';
import { GetVisualMedia } from '@/types/definitions';
import { getServerUser } from '@/lib/getServerUser';

export async function GET(request: Request, props: { params: Promise<{ userId: string }> }) {
  const params = await props.params;
  const [user] = await getServerUser();
  if (user && user.id !== params.userId) {
    const block = await prisma.userBlock.findFirst({
      where: {
        OR: [
          { blockerId: user.id, blockedId: params.userId },
          { blockerId: params.userId, blockedId: user.id },
        ],
      },
      select: { id: true },
    });
    if (block) return NextResponse.json([]);
  }
  const res = await prisma.visualMedia.findMany({
    where: {
      userId: params.userId,
      ...(user?.id === params.userId
        ? {}
        : {
            post: {
              is: {
                displayIdentity: 'USER' as const,
                status: 'PUBLISHED' as const,
                moderationCases: { none: { status: 'OPEN' as const } },
              },
            },
          }),
    },
    orderBy: {
      id: 'desc',
    },
  });

  const visualMedia: GetVisualMedia[] | null = res.map((item) => ({
    type: item.type,
    url: fileNameToUrl(item.fileName)!,
  }));

  return NextResponse.json(visualMedia);
}
