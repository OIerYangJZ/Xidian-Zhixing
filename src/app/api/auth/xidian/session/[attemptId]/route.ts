import prisma from '@/lib/prisma/prisma';
import { apiError, apiSuccess } from '@/lib/apiResponse';

export async function GET(_request: Request, { params }: { params: { attemptId: string } }) {
  const attempt = await prisma.xidianLoginAttempt.findUnique({
    where: { id: params.attemptId },
    select: { status: true, callbackUrl: true, expiresAt: true, consumedAt: true },
  });
  if (!attempt) return apiError('登录尝试不存在。', 404);
  if (attempt.expiresAt <= new Date()) return apiSuccess({ status: 'expired' });
  if (attempt.consumedAt) return apiSuccess({ status: 'consumed' });
  return apiSuccess({ status: attempt.status.toLowerCase(), callbackUrl: attempt.callbackUrl });
}
