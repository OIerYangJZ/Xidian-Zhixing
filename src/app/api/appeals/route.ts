import { auth } from '@/auth';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';
import { z } from 'zod';

const schema = z.object({ caseId: z.string().min(1), reason: z.string().trim().min(10).max(2000) });

export async function GET() {
  const session = await auth();
  if (!session?.user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  const cases = await prisma.moderationCase.findMany({
    where: {
      status: { in: ['RESOLVED', 'APPEALED'] },
      OR: [{ post: { is: { userId: session.user.id } } }, { comment: { is: { userId: session.user.id } } }],
      action: { in: ['REMOVE_CONTENT', 'SUSPEND_USER'] },
    },
    select: {
      id: true,
      action: true,
      status: true,
      notes: true,
      postId: true,
      commentId: true,
      appeals: { select: { id: true, resolvedAt: true }, where: { userId: session.user.id } },
    },
    orderBy: { createdAt: 'desc' },
  });
  return NextResponse.json(cases);
}

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: 'invalid_request' }, { status: 400 });
  const moderationCase = await prisma.moderationCase.findFirst({
    where: {
      id: parsed.data.caseId,
      status: 'RESOLVED',
      action: { in: ['REMOVE_CONTENT', 'SUSPEND_USER'] },
      OR: [{ post: { is: { userId: session.user.id } } }, { comment: { is: { userId: session.user.id } } }],
      appeals: { none: { userId: session.user.id } },
    },
    select: { id: true },
  });
  if (!moderationCase) return NextResponse.json({ error: 'not_appealable' }, { status: 404 });
  const appeal = await prisma.$transaction(async (tx) => {
    const created = await tx.appeal.create({
      data: { caseId: moderationCase.id, userId: session.user.id, reason: parsed.data.reason },
      select: { id: true },
    });
    await tx.moderationCase.update({ where: { id: moderationCase.id }, data: { status: 'APPEALED' } });
    return created;
  });
  return NextResponse.json(appeal, { status: 201 });
}
