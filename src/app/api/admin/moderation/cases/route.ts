import { getKnowledgeAdmin } from '@/lib/ai/admin';
import { apiError, apiSuccess } from '@/lib/apiResponse';
import { fileNameToUrl } from '@/lib/s3/fileNameToUrl';
import prisma from '@/lib/prisma/prisma';

export async function GET() {
  if (!(await getKnowledgeAdmin())) return apiError('需要管理员权限。', 403);
  const cases = await prisma.moderationCase.findMany({
    where: { status: { in: ['OPEN', 'APPEALED'] } },
    orderBy: { createdAt: 'asc' },
    include: {
      openedBy: { select: { id: true, username: true, name: true } },
      report: { select: { reason: true, details: true } },
      appeals: { where: { resolvedAt: null }, select: { id: true, reason: true, createdAt: true } },
      post: {
        select: {
          id: true,
          content: true,
          createdAt: true,
          visualMedia: { select: { type: true, fileName: true } },
          user: { select: { id: true, username: true, name: true, status: true } },
        },
      },
      comment: {
        select: { id: true, content: true, user: { select: { id: true, username: true, name: true, status: true } } },
      },
    },
  });
  return apiSuccess({
    items: cases.map((item) => ({
      id: item.id,
      status: item.status,
      notes: item.notes,
      report: item.report,
      appeal: item.appeals[0] || null,
      createdAt: item.createdAt,
      openedBy: item.openedBy,
      post: item.post && {
        ...item.post,
        visualMedia: item.post.visualMedia.map(({ type, fileName }) => ({ type, url: fileNameToUrl(fileName) })),
      },
      comment: item.comment && { ...item.comment, content: item.removedCommentContent || item.comment.content },
    })),
  });
}
