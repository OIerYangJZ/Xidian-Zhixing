import { apiError, apiSuccess } from '@/lib/apiResponse';
import { campusMaps } from '@/lib/campus/catalog';
import { getServerUser } from '@/lib/getServerUser';

export async function GET() {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  return apiSuccess({ items: campusMaps, sourceStatus: 'not_connected' });
}
