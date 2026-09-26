import { getKnowledgeAdmin } from '@/lib/ai/admin';
import { apiError, apiSuccess } from '@/lib/apiResponse';
import prisma from '@/lib/prisma/prisma';

type RouteContext = { params: { caseId: string } };

export async function PATCH(request: Request, { params }: RouteContext) {
  const admin = await getKnowledgeAdmin();
  if (!admin) return apiError('需要管理员权限。', 403);

  const body = (await request.json().catch(() => null)) as { decision?: unknown; note?: unknown } | null;
  if (body?.decision !== 'approve' && body?.decision !== 'remove') {
    return apiError('审核操作无效。', 400);
  }
  const note = typeof body.note === 'string' ? body.note.trim().slice(0, 1000) : '';

  const result = await prisma.$transaction(async (tx) => {
    const moderationCase = await tx.moderationCase.findFirst({
      where: { id: params.caseId, status: 'OPEN', postId: { not: null } },
      select: { id: true, postId: true, notes: true },
    });
    if (!moderationCase?.postId) return null;

    const now = new Date();
    await tx.moderationCase.update({
      where: { id: moderationCase.id },
      data: {
        status: 'RESOLVED',
        action: body.decision === 'remove' ? 'REMOVE_CONTENT' : 'NO_ACTION',
        assignedToId: admin.id,
        resolvedAt: now,
        notes: [moderationCase.notes, note ? `管理员备注：${note}` : ''].filter(Boolean).join('\n'),
      },
    });

    if (body.decision === 'remove') {
      await tx.post.update({ where: { id: moderationCase.postId }, data: { status: 'REMOVED' } });
    } else {
      const openCases = await tx.moderationCase.count({ where: { postId: moderationCase.postId, status: 'OPEN' } });
      if (openCases === 0) {
        await tx.post.update({ where: { id: moderationCase.postId }, data: { status: 'PUBLISHED' } });
      }
    }
    return { caseId: moderationCase.id, postId: moderationCase.postId };
  });

  if (!result) return apiError('审核事项已处理或不存在。', 404);
  return apiSuccess(result);
}
