import { getKnowledgeAdmin } from '@/lib/ai/admin';
import { apiError, apiSuccess } from '@/lib/apiResponse';
import prisma from '@/lib/prisma/prisma';

type RouteContext = { params: Promise<{ caseId: string }> };

export async function PATCH(request: Request, props: RouteContext) {
  const { caseId } = await props.params;
  const admin = await getKnowledgeAdmin();
  if (!admin) return apiError('需要管理员权限。', 403);
  const body = (await request.json().catch(() => null)) as { decision?: unknown; note?: unknown } | null;
  const decision = body?.decision;
  if (!['approve', 'remove', 'suspend', 'restore', 'reject_appeal'].includes(String(decision))) {
    return apiError('审核操作无效。', 400);
  }
  const note = typeof body?.note === 'string' ? body.note.trim().slice(0, 1000) : '';
  const result = await prisma.$transaction(async (tx) => {
    const item = await tx.moderationCase.findFirst({
      where: { id: caseId, status: { in: ['OPEN', 'APPEALED'] } },
      include: {
        post: { select: { userId: true, status: true } },
        comment: { select: { userId: true, content: true } },
        appeals: { where: { resolvedAt: null }, select: { id: true } },
      },
    });
    if (!item || (!item.post && !item.comment)) return null;
    const authorId = item.post?.userId || item.comment!.userId;
    if (decision === 'suspend' && authorId === admin.id) return null;
    if (item.status === 'OPEN' && !['approve', 'remove', 'suspend'].includes(String(decision))) return null;
    if (item.status === 'APPEALED' && !['restore', 'reject_appeal'].includes(String(decision))) return null;
    const now = new Date();
    if (item.status === 'OPEN') {
      if (decision === 'remove' || decision === 'suspend') {
        if (item.postId) await tx.post.update({ where: { id: item.postId }, data: { status: 'REMOVED' } });
        if (item.commentId) await tx.comment.update({ where: { id: item.commentId }, data: { content: '[此评论已被移除]' } });
      }
      if (decision === 'suspend') await tx.user.update({ where: { id: authorId }, data: { status: 'SUSPENDED' } });
      if (decision === 'approve' && item.postId) {
        const otherOpen = await tx.moderationCase.count({ where: { postId: item.postId, status: 'OPEN', id: { not: item.id } } });
        if (otherOpen === 0 && item.post?.status === 'HIDDEN') {
          await tx.post.update({ where: { id: item.postId }, data: { status: 'PUBLISHED' } });
        }
      }
      await tx.moderationCase.update({
        where: { id: item.id },
        data: {
          status: 'RESOLVED',
          action: decision === 'suspend' ? 'SUSPEND_USER' : decision === 'remove' ? 'REMOVE_CONTENT' : 'NO_ACTION',
          removedCommentContent: decision !== 'approve' ? item.comment?.content : null,
          assignedToId: admin.id,
          resolvedAt: now,
          notes: [item.notes, note ? `管理员备注：${note}` : ''].filter(Boolean).join('\n'),
        },
      });
    } else {
      if (decision === 'restore') {
        const otherOpen = await tx.moderationCase.count({
          where: {
            id: { not: item.id }, status: 'OPEN',
            ...(item.postId ? { postId: item.postId } : { commentId: item.commentId }),
          },
        });
        if (otherOpen > 0) return null;
        if (item.postId) await tx.post.update({ where: { id: item.postId }, data: { status: 'PUBLISHED' } });
        if (item.commentId && item.removedCommentContent) {
          await tx.comment.update({ where: { id: item.commentId }, data: { content: item.removedCommentContent } });
        }
        if (item.action === 'SUSPEND_USER') await tx.user.update({ where: { id: authorId }, data: { status: 'ACTIVE' } });
      }
      await tx.appeal.updateMany({ where: { id: { in: item.appeals.map(({ id }) => id) } }, data: { resolvedAt: now } });
      await tx.moderationCase.update({
        where: { id: item.id },
        data: {
          status: 'RESOLVED',
          ...(decision === 'restore' ? { action: 'NO_ACTION' as const } : {}),
          assignedToId: admin.id,
          notes: [item.notes, note ? `申诉处理：${note}` : ''].filter(Boolean).join('\n'),
        },
      });
    }
    await tx.auditLog.create({
      data: { actorUserId: admin.id, action: `moderation.${decision}`, subjectType: 'ModerationCase', subjectId: item.id, details: { note } },
    });
    return { caseId: item.id, postId: item.postId, commentId: item.commentId };
  });
  if (!result) return apiError('审核事项已处理或不存在。', 404);
  return apiSuccess(result);
}
