import { apiError, apiSuccess } from '@/lib/apiResponse';
import { createMiniProgramToken } from '@/lib/auth/miniProgramToken';
import { seedLocalTestData } from '@/lib/dev/seedLocalTestData';
import { includeToUser } from '@/lib/prisma/includeToUser';
import prisma from '@/lib/prisma/prisma';
import { toGetUser } from '@/lib/prisma/toGetUser';

export async function POST() {
  if (process.env.NODE_ENV === 'production' || process.env.LOCAL_TEST_AUTH !== 'true') {
    return apiError('Not found.', 404);
  }

  let databaseHost = '';
  try {
    databaseHost = new URL(process.env.DATABASE_URL || '').hostname;
  } catch {
    return apiError('本地测试登录仅允许连接本机数据库。', 404);
  }
  if (!['localhost', '127.0.0.1', '[::1]', '::1'].includes(databaseHost)) {
    return apiError('本地测试登录仅允许连接本机数据库。', 404);
  }

  try {
    const user = await prisma.user.upsert({
      where: { id: 'local-test-student' },
      update: { status: 'ACTIVE', role: 'ADMIN' },
      create: {
        id: 'local-test-student',
        username: 'localtest',
        name: '本地测试同学',
        role: 'ADMIN',
      },
      select: { id: true },
    });

    await seedLocalTestData(user.id);
    const account = await prisma.user.findUnique({
      where: { id: user.id },
      include: includeToUser(user.id),
    });
    if (!account) return apiError('本地测试账号不存在。', 503);

    return apiSuccess({ ...createMiniProgramToken(user.id), user: toGetUser(account) });
  } catch (error) {
    console.error('[local-test-auth] session creation failed', error);
    return apiError('本地测试登录失败，请检查开发数据库。', 503);
  }
}
