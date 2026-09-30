import { NextResponse } from 'next/server';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { selectPost } from '@/lib/prisma/selectPost';
import { toGetPost } from '@/lib/prisma/toGetPost';

const CANDIDATE_LIMIT = 500;
const WINDOW_HOURS = 24 * 7;

export async function GET(request: Request) {
  const [user] = await getServerUser();
  if (!user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const { searchParams } = new URL(request.url);
  const limit = Math.min(Math.max(Number(searchParams.get('limit')) || 20, 1), 50);
  const offset = Math.max(Number(searchParams.get('cursor')) || 0, 0);
  const rawSpaceId = searchParams.get('spaceId');
  const spaceId = rawSpaceId ? Number(rawSpaceId) : undefined;
  if (rawSpaceId && (!Number.isInteger(spaceId) || Number(spaceId) <= 0)) {
    return NextResponse.json({ error: 'invalid_space' }, { status: 400 });
  }

  const since = new Date(Date.now() - WINDOW_HOURS * 60 * 60 * 1000);
  const candidates = await prisma.post.findMany({
    where: {
      status: 'PUBLISHED',
      createdAt: { gte: since },
      ...(spaceId ? { spaceId } : {}),
      moderationCases: { none: { status: 'OPEN' } },
      NOT: [
        { user: { blocksMade: { some: { blockedId: user.id } } } },
        { user: { blocksReceived: { some: { blockerId: user.id } } } },
      ],
    },
    orderBy: { createdAt: 'desc' },
    take: CANDIDATE_LIMIT,
    select: selectPost(user.id),
  });

  const ranked = candidates
    .map((post) => {
      const ageHours = Math.max(0, (Date.now() - post.createdAt.getTime()) / 3_600_000);
      const engagement = post._count.postLikes + post._count.comments * 2 + post._count.reposts * 3;
      const hotScore = Number(((engagement + Math.log10(post.viewCount + 1)) / (1 + ageHours / 24)).toFixed(2));
      return { post, hotScore };
    })
    .sort((a, b) => b.hotScore - a.hotScore || b.post.createdAt.getTime() - a.post.createdAt.getTime());

  const page = ranked.slice(offset, offset + limit);
  const items = await Promise.all(page.map(async ({ post, hotScore }, index) => ({
    ...(await toGetPost(post, user.id)),
    hotScore,
    feedCursor: String(offset + index + 1),
  })));

  return NextResponse.json({ items, hasMore: offset + items.length < ranked.length });
}
