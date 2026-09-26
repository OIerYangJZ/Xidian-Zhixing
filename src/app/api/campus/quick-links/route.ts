import { apiError, apiSuccess } from '@/lib/apiResponse';
import { campusQuickLinks } from '@/lib/campus/catalog';
import { getServerUser } from '@/lib/getServerUser';

export async function GET() {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  return apiSuccess(campusQuickLinks);
}
