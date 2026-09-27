import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

export async function GET() {
  const [user] = await getServerUser();
  if (!user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const conversations = await prisma.aiConversation.findMany({
    where: { userId: user.id },
    orderBy: { updatedAt: 'desc' },
    include: {
      messages: { orderBy: { createdAt: 'asc' }, take: 40 },
    },
  });

  return NextResponse.json(conversations);
}

export async function POST() {
  const [user] = await getServerUser();
  if (!user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const conversation = await prisma.aiConversation.create({
    data: { userId: user.id, title: '新对话' },
  });

  return NextResponse.json(conversation, { status: 201 });
}
