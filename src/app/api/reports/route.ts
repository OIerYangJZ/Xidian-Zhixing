import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';
import { z } from 'zod';

const schema = z
  .object({
    postId: z.number().int().positive().optional(),
    commentId: z.number().int().positive().optional(),
    reason: z.enum(['SPAM', 'HARASSMENT', 'MISINFORMATION', 'INAPPROPRIATE_CONTENT', 'OTHER']),
    details: z.string().trim().max(1000).optional(),
  })
  .refine(({ postId, commentId }) => Number(!!postId) + Number(!!commentId) === 1);

export async function POST(request: Request) {
  const [user] = await getServerUser();
  if (!user?.id) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: 'invalid_request' }, { status: 400 });
  const { postId, commentId, reason, details } = parsed.data;
  const targetPost = postId
    ? await prisma.post.findFirst({ where: { id: postId, status: 'PUBLISHED' }, select: { userId: true } })
    : null;
  const targetComment = commentId
    ? await prisma.comment.findUnique({ where: { id: commentId }, select: { userId: true, postId: true } })
    : null;
  const target = targetPost || targetComment;
  if (!target) return NextResponse.json({ error: 'not_found' }, { status: 404 });
  if (target.userId === user.id) return NextResponse.json({ error: 'own_content' }, { status: 400 });
  const existing = await prisma.report.findFirst({
    where: { reporterId: user.id, ...(postId ? { postId } : { commentId }), case: { is: { status: 'OPEN' } } },
    select: { id: true },
  });
  if (existing) return NextResponse.json({ id: existing.id }, { status: 200 });
  const report = await prisma.$transaction(async (tx) => {
    const created = await tx.report.create({
      data: { reporterId: user.id, postId, commentId, reason, details },
      select: { id: true },
    });
    await tx.moderationCase.create({
      data: {
        reportId: created.id,
        postId: postId ?? targetComment!.postId,
        commentId,
        openedById: user.id,
        notes: details || reason,
      },
    });
    return created;
  });
  return NextResponse.json(report, { status: 201 });
}
