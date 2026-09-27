import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

const privacyFields = ['allowStrangerDm', 'showContactable'] as const;
const notificationFields = [
  'follows',
  'likes',
  'comments',
  'messages',
  'replies',
  'favorites',
  'reportResults',
  'system',
] as const;

export async function GET() {
  const [user] = await getServerUser();
  if (!user) return NextResponse.json({ error: 'Unauthorized.' }, { status: 401 });
  const [privacy, notifications] = await Promise.all([
    prisma.user.findUnique({ where: { id: user.id }, select: { allowStrangerDm: true, showContactable: true } }),
    prisma.notificationPreference.upsert({ where: { userId: user.id }, create: { userId: user.id }, update: {} }),
  ]);
  return NextResponse.json({ privacy, notifications });
}

export async function PATCH(request: Request) {
  const [user] = await getServerUser();
  if (!user) return NextResponse.json({ error: 'Unauthorized.' }, { status: 401 });
  const body = (await request.json()) as { privacy?: Record<string, unknown>; notifications?: Record<string, unknown> };
  const privacy = Object.fromEntries(
    privacyFields.filter((key) => typeof body.privacy?.[key] === 'boolean').map((key) => [key, body.privacy?.[key]]),
  );
  const notifications = Object.fromEntries(
    notificationFields
      .filter((key) => typeof body.notifications?.[key] === 'boolean')
      .map((key) => [key, body.notifications?.[key]]),
  );
  const results = await Promise.all([
    Object.keys(privacy).length ? prisma.user.update({ where: { id: user.id }, data: privacy }) : Promise.resolve(null),
    Object.keys(notifications).length
      ? prisma.notificationPreference.upsert({
          where: { userId: user.id },
          create: { userId: user.id, ...notifications },
          update: notifications,
        })
      : Promise.resolve(null),
  ]);
  return NextResponse.json({ saved: true, results });
}
