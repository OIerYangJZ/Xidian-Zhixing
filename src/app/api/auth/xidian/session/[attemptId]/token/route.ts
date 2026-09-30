import { createMiniProgramToken } from '@/lib/auth/miniProgramToken';
import prisma from '@/lib/prisma/prisma';
import { apiError, apiSuccess } from '@/lib/apiResponse';

const MINI_PROGRAM_CALLBACK = '/miniprogram-auth';

export async function POST(_request: Request, props: { params: Promise<{ attemptId: string }> }) {
  const { attemptId } = await props.params;
  const attempt = await prisma.xidianLoginAttempt.findUnique({
    where: { id: attemptId },
    select: { callbackUrl: true, status: true, userId: true, expiresAt: true, consumedAt: true },
  });

  if (
    !attempt ||
    attempt.callbackUrl !== MINI_PROGRAM_CALLBACK ||
    attempt.status !== 'APPROVED' ||
    !attempt.userId ||
    attempt.consumedAt ||
    attempt.expiresAt <= new Date()
  ) {
    return apiError('小程序登录会话已失效，请重新登录。', 409);
  }

  let session;
  try {
    session = createMiniProgramToken(attempt.userId);
  } catch {
    return apiError('小程序登录暂时不可用。', 503);
  }

  const claimed = await prisma.xidianLoginAttempt.updateMany({
    where: {
      id: attemptId,
      callbackUrl: MINI_PROGRAM_CALLBACK,
      status: 'APPROVED',
      userId: attempt.userId,
      consumedAt: null,
      expiresAt: { gt: new Date() },
    },
    data: { consumedAt: new Date() },
  });
  if (claimed.count !== 1) return apiError('小程序登录会话已被使用，请重新登录。', 409);

  const user = await prisma.user.findUnique({
    where: { id: attempt.userId },
    select: { id: true, username: true, name: true, profilePhoto: true, role: true },
  });
  if (!user) return apiError('账号不存在。', 404);

  return apiSuccess({ ...session, user });
}
