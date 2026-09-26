import { getKnowledgeAdmin } from '@/lib/ai/admin';
import { apiError, apiSuccess } from '@/lib/apiResponse';
import { fileNameToUrl } from '@/lib/s3/fileNameToUrl';
import prisma from '@/lib/prisma/prisma';

export async function GET() {
  if (!(await getKnowledgeAdmin())) return apiError('需要管理员权限。', 403);

  const cases = await prisma.moderationCase.findMany({
    where: { status: 'OPEN', postId: { not: null } },
    orderBy: { createdAt: 'asc' },
    include: {
      openedBy: { select: { id: true, username: true, name: true } },
      post: {
        select: {
          id: true,
          content: true,
          createdAt: true,
          visualMedia: { select: { id: true, type: true, fileName: true } },
          user: { select: { id: true, username: true, name: true } },
        },
      },
    },
  });

  return apiSuccess({
    items: cases
      .filter((item) => item.post)
      .map((item) => ({
        id: item.id,
        notes: item.notes,
        createdAt: item.createdAt,
        openedBy: item.openedBy,
        post: {
          ...item.post!,
          visualMedia: item.post!.visualMedia.map(({ type, fileName }) => ({ type, url: fileNameToUrl(fileName) })),
        },
      })),
  });
}
