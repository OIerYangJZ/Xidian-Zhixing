import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';
import { CampusAuthError, createDormWaterCaptcha } from '@/lib/campus/upstreamAuth';

export async function POST() {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  try {
    return apiSuccess(await createDormWaterCaptcha(user.id));
  } catch (error) {
    if (error instanceof CampusAuthError) return apiError(error.message, error.status);
    return apiError('宿舍水机验证码获取失败。', 503);
  }
}
