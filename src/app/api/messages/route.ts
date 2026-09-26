import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

export async function GET() {
  const [user] = await getServerUser();
  if (!user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const memberships = await prisma.conversationParticipant.findMany({
    where: { userId: user.id, archivedAt: null },
    include: {
      conversation: {
        include: {
          messages: { where: { deletedAt: null }, orderBy: { createdAt: 'desc' }, take: 1 },
          participants: {
            where: { userId: { not: user.id } },
            include: {
              user: { select: { id: true, username: true, name: true, profilePhoto: true, status: true } },
            },
          },
        },
      },
    },
    orderBy: { conversation: { updatedAt: 'desc' } },
  });

  const peerIds = memberships.flatMap(({ conversation }) =>
    conversation.participants.map(({ user: participantUser }) => participantUser.id),
  );
  const blockedPeers = await prisma.userBlock.findMany({
    where: {
      OR: [
        { blockerId: user.id, blockedId: { in: peerIds } },
        { blockedId: user.id, blockerId: { in: peerIds } },
      ],
    },
    select: { blockerId: true, blockedId: true },
  });
  const blockedIds = new Set(
    blockedPeers.map(({ blockerId, blockedId }) => (blockerId === user.id ? blockedId : blockerId)),
  );

  const conversations = memberships
    .map(({ conversation }) => {
      const participant = conversation.participants[0];
      if (!participant || participant.user.status !== 'ACTIVE' || blockedIds.has(participant.user.id)) return null;
      return {
        id: conversation.id,
        updatedAt: conversation.updatedAt,
        participant: {
          id: participant.user.id,
          username: participant.user.username,
          name: participant.user.name,
          profilePhoto: participant.user.profilePhoto,
        },
        lastMessage: conversation.messages[0] || null,
      };
    })
    .filter((conversation) => conversation !== null);

  return NextResponse.json(conversations);
}

export async function POST(request: Request) {
  const [user] = await getServerUser();
  if (!user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const body = (await request.json().catch(() => null)) as { username?: unknown } | null;
  const username = typeof body?.username === 'string' ? body.username.trim() : '';
  if (!username) return NextResponse.json({ error: 'invalid_request' }, { status: 400 });

  const recipient = await prisma.user.findFirst({
    where: { username, status: 'ACTIVE', id: { not: user.id } },
    select: { id: true, allowStrangerDm: true, following: { where: { followingId: user.id }, select: { id: true } } },
  });
  if (!recipient) return NextResponse.json({ error: 'user_not_found' }, { status: 404 });

  const block = await prisma.userBlock.findFirst({
    where: {
      OR: [
        { blockerId: user.id, blockedId: recipient.id },
        { blockerId: recipient.id, blockedId: user.id },
      ],
    },
  });
  if (block) return NextResponse.json({ error: 'conversation_blocked' }, { status: 403 });

  const existing = await prisma.conversation.findFirst({
    where: {
      participants: {
        every: { userId: { in: [user.id, recipient.id] } },
      },
      AND: [{ participants: { some: { userId: user.id } } }, { participants: { some: { userId: recipient.id } } }],
    },
    select: { id: true },
  });

  if (!existing && !recipient.allowStrangerDm && recipient.following.length === 0) {
    return NextResponse.json({ error: 'direct_messages_not_allowed' }, { status: 403 });
  }

  const conversation =
    existing ||
    (await prisma.conversation.create({
      data: {
        participants: {
          create: [{ userId: user.id }, { userId: recipient.id }],
        },
      },
      select: { id: true },
    }));

  if (existing) {
    await prisma.conversationParticipant.updateMany({
      where: { conversationId: existing.id, userId: { in: [user.id, recipient.id] } },
      data: { archivedAt: null },
    });
  }

  return NextResponse.json({ id: conversation.id }, { status: existing ? 200 : 201 });
}
