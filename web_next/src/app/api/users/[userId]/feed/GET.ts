/**
 * GET /api/users/:userId/feed
 * - Allows an authenticated user to retrieve the most recent posts
 * posted by the user and their followed users.
 */

import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { selectPost } from '@/lib/prisma/selectPost';
import { toGetPost } from '@/lib/prisma/toGetPost';
import { NextResponse } from 'next/server';
import { GetPost } from '@/types/definitions';

const PAGE_SIZE = 25;

type FeedCursor = { createdAt: string; eventKey: string };
type FeedEntry = {
  createdAt: Date;
  eventKey: string;
  post: Awaited<ReturnType<typeof toGetPost>>;
  repostedBy?: { id: string; username: string | null; name: string | null; profilePhoto: string | null };
};

function parseCursor(value: string | null): FeedCursor | null {
  if (!value || value === '0') return null;
  const separator = value.indexOf('|');
  if (separator < 1) return null;
  const createdAt = value.slice(0, separator);
  const eventKey = value.slice(separator + 1);
  if (!Number.isFinite(new Date(createdAt).getTime()) || !/^[pr]:\d+$/.test(eventKey)) return null;
  return { createdAt, eventKey };
}

function eventCursor(entry: FeedEntry) {
  return `${entry.createdAt.toISOString()}|${entry.eventKey}`;
}

export async function GET(request: Request, props: { params: Promise<{ userId: string }> }) {
  const params = await props.params;
  const { searchParams } = new URL(request.url);
  const cursorValue = searchParams.get('cursor');
  const cursor = parseCursor(cursorValue);
  const isNewer = searchParams.get('sort-direction') === 'asc';
  if (cursorValue && cursorValue !== '0' && !cursor)
    return NextResponse.json({ error: 'Invalid feed cursor.' }, { status: 400 });
  const pageSize = Math.min(Math.max(Number(searchParams.get('limit')) || PAGE_SIZE, 1), 100);

  const [user] = await getServerUser();
  if (!user || params.userId !== user.id) return NextResponse.json({}, { status: 401 });

  // Get the IDs of the user's followed users
  const following = await prisma.follow.findMany({
    where: {
      followerId: user.id,
    },
    select: {
      followingId: true,
    },
  });
  const followingIds = following.map((u) => u.followingId);

  const visiblePostWhere = {
    status: 'PUBLISHED' as const,
    moderationCases: { none: { status: 'OPEN' as const } },
    NOT: [
      { user: { blocksMade: { some: { blockedId: user.id } } } },
      { user: { blocksReceived: { some: { blockerId: user.id } } } },
    ],
  };
  const visibleReposterWhere = {
    NOT: [
      { user: { blocksMade: { some: { blockedId: user.id } } } },
      { user: { blocksReceived: { some: { blockerId: user.id } } } },
    ],
  };
  const streamQuery = async <T>(fetchBefore: () => Promise<T[]>, fetchAtCursor: () => Promise<T[]>) => {
    if (!cursor) return fetchBefore();
    const [before, sameTime] = await Promise.all([fetchBefore(), fetchAtCursor()]);
    return [...before, ...sameTime];
  };
  const [postRows, repostRows] = await Promise.all([
    streamQuery(
      () =>
        prisma.post.findMany({
          where: {
            OR: [
              { userId: { in: [...followingIds, user.id] }, displayIdentity: { not: 'ANONYMOUS' } },
              { displayIdentity: 'ANONYMOUS' },
            ],
            ...visiblePostWhere,
            ...(cursor && {
              createdAt: isNewer ? { gt: new Date(cursor.createdAt) } : { lt: new Date(cursor.createdAt) },
            }),
          },
          orderBy: { createdAt: isNewer ? 'asc' : 'desc' },
          take: pageSize,
          select: selectPost(user.id),
        }),
      () =>
        cursor
          ? prisma.post.findMany({
              where: {
                OR: [
                  { userId: { in: [...followingIds, user.id] }, displayIdentity: { not: 'ANONYMOUS' } },
                  { displayIdentity: 'ANONYMOUS' },
                ],
                ...visiblePostWhere,
                createdAt: new Date(cursor.createdAt),
              },
              select: selectPost(user.id),
            })
          : Promise.resolve([]),
    ),
    streamQuery(
      () =>
        prisma.repost.findMany({
          where: {
            userId: { in: [...followingIds, user.id] },
            ...visibleReposterWhere,
            post: { is: visiblePostWhere },
            ...(cursor && {
              createdAt: isNewer ? { gt: new Date(cursor.createdAt) } : { lt: new Date(cursor.createdAt) },
            }),
          },
          orderBy: { createdAt: isNewer ? 'asc' : 'desc' },
          take: pageSize,
          include: {
            user: { select: { id: true, username: true, name: true, profilePhoto: true } },
            post: { select: selectPost(user.id) },
          },
        }),
      () =>
        cursor
          ? prisma.repost.findMany({
              where: {
                userId: { in: [...followingIds, user.id] },
                ...visibleReposterWhere,
                post: { is: visiblePostWhere },
                createdAt: new Date(cursor.createdAt),
              },
              include: {
                user: { select: { id: true, username: true, name: true, profilePhoto: true } },
                post: { select: selectPost(user.id) },
              },
            })
          : Promise.resolve([]),
    ),
  ]);

  const entries: FeedEntry[] = await Promise.all([
    ...postRows.map(async (post) => ({
      createdAt: post.createdAt,
      eventKey: `p:${String(post.id).padStart(12, '0')}`,
      post: await toGetPost(post, user.id),
    })),
    ...repostRows.map(async (repost) => ({
      createdAt: repost.createdAt,
      eventKey: `r:${String(repost.id).padStart(12, '0')}`,
      post: await toGetPost(repost.post, user.id),
      repostedBy: repost.user,
    })),
  ]);
  const cursorTime = cursor ? new Date(cursor.createdAt).getTime() : null;
  const inDirection = entries.filter((entry) => {
    if (!cursor || cursorTime === null) return true;
    const time = entry.createdAt.getTime();
    if (isNewer && time !== cursorTime) return time > cursorTime;
    if (!isNewer && time !== cursorTime) return time < cursorTime;
    return isNewer ? entry.eventKey > cursor.eventKey : entry.eventKey < cursor.eventKey;
  });
  inDirection.sort((a, b) => {
    const timeDifference = a.createdAt.getTime() - b.createdAt.getTime();
    const order = timeDifference || a.eventKey.localeCompare(b.eventKey);
    return isNewer ? order : -order;
  });
  const page = inDirection.slice(0, pageSize);
  const response = page.map((entry) => ({
    ...entry.post,
    feedEventKey: entry.eventKey,
    feedCursor: eventCursor(entry),
    repostedBy: entry.repostedBy,
  }));

  return NextResponse.json<
    Array<
      GetPost & {
        feedEventKey: string;
        feedCursor: string;
        repostedBy?: { id: string; username: string | null; name: string | null; profilePhoto: string | null };
      }
    >
  >(response);
}
