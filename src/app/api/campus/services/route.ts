import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';
import { getCampusServices } from '@/lib/campus/catalog';
import prisma from '@/lib/prisma/prisma';

export async function GET() {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  const identityCount = await prisma.institutionIdentity.count({ where: { userId: user.id } });
  return apiSuccess(getCampusServices(identityCount > 0));
}
