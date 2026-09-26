import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';
import { getCampusServices } from '@/lib/campus/catalog';
import prisma from '@/lib/prisma/prisma';

export async function GET(_request: Request, { params }: { params: { serviceId: string } }) {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  const identityCount = await prisma.institutionIdentity.count({ where: { userId: user.id } });
  const service = getCampusServices(identityCount > 0).find(
    ({ id, slug }) => id === params.serviceId || slug === params.serviceId,
  );
  if (!service) return apiError('没有找到这个校园服务。', 404);
  return apiSuccess(service);
}
