import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';
import { fileNameToUrl } from '@/lib/s3/fileNameToUrl';

export async function GET(_request: Request, props: { params: Promise<{ conversationId: string }> }) {
  const params = await props.params;
  const [user] = await getServerUser();
  if (!user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const participant = await prisma.conversationParticipant.findFirst({
    where: { conversationId: params.conversationId, userId: user.id, archivedAt: null },
    include: {
      conversation: {
        include: {
          participants: {
            include: {
              user: { select: { id: true, username: true, name: true, profilePhoto: true, status: true } },
            },
          },
          messages: {
            where: { deletedAt: null },
            orderBy: { createdAt: 'desc' },
            take: 100,
          },
        },
      },
    },
  });

  if (!participant) return NextResponse.json({ error: 'not_found' }, { status: 404 });
  const isBlocked = await prisma.userBlock.findFirst({
    where: {
      OR: [
        { blockerId: user.id, blockedId: { in: participant.conversation.participants.map(({ userId }) => userId) } },
        { blockedId: user.id, blockerId: { in: participant.conversation.participants.map(({ userId }) => userId) } },
      ],
    },
  });
  if (isBlocked) return NextResponse.json({ error: 'not_found' }, { status: 404 });

  await prisma.conversationParticipant.update({ where: { id: participant.id }, data: { lastReadAt: new Date() } });
  return NextResponse.json({
    id: participant.conversation.id,
    participants: participant.conversation.participants
      .filter(({ user: participantUser }) => participantUser.status === 'ACTIVE')
      .map(({ user: participantUser }) => ({
        id: participantUser.id,
        username: participantUser.username,
        name: participantUser.name,
        profilePhoto: fileNameToUrl(participantUser.profilePhoto),
      })),
    messages: participant.conversation.messages.reverse(),
  });
}

export async function PATCH(_request: Request, props: { params: Promise<{ conversationId: string }> }) {
  const { conversationId } = await props.params;
  const [user] = await getServerUser();
  if (!user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  const result = await prisma.conversationParticipant.updateMany({
    where: { conversationId, userId: user.id, archivedAt: null },
    data: { archivedAt: new Date() },
  });
  if (!result.count) return NextResponse.json({ error: 'not_found' }, { status: 404 });
  return NextResponse.json({ archived: true });
}
