import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';
import { z } from 'zod';

const messageSchema = z.object({ content: z.string().trim().min(1).max(4000) });

export async function POST(request: Request, props: { params: Promise<{ conversationId: string }> }) {
  const params = await props.params;
  const [user] = await getServerUser();
  if (!user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  const parsed = messageSchema.safeParse(await request.json());
  if (!parsed.success) return NextResponse.json({ error: 'invalid_request' }, { status: 400 });

  const participants = await prisma.conversationParticipant.findMany({
    where: { conversationId: params.conversationId, archivedAt: null },
    select: { userId: true },
  });
  if (!participants.some(({ userId }) => userId === user.id)) {
    return NextResponse.json({ error: 'not_found' }, { status: 404 });
  }

  const peerIds = participants.filter(({ userId }) => userId !== user.id).map(({ userId }) => userId);
  const block = await prisma.userBlock.findFirst({
    where: {
      OR: [
        { blockerId: user.id, blockedId: { in: peerIds } },
        { blockedId: user.id, blockerId: { in: peerIds } },
      ],
    },
  });
  if (block) return NextResponse.json({ error: 'conversation_blocked' }, { status: 403 });

  const [message] = await prisma.$transaction([
    prisma.message.create({
      data: { conversationId: params.conversationId, senderId: user.id, content: parsed.data.content },
    }),
    prisma.conversation.update({ where: { id: params.conversationId }, data: { updatedAt: new Date() } }),
  ]);

  return NextResponse.json(message, { status: 201 });
}
