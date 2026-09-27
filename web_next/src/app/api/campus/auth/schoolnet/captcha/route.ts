import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getXidianStudentId } from '@/lib/auth/xidianCas';
import { getServerUser } from '@/lib/getServerUser';
import { CampusAuthError, createSchoolnetCaptcha } from '@/lib/campus/upstreamAuth';

export async function POST() {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  const studentId = await getXidianStudentId(user.id);
  if (!studentId) return apiError('请先完成西电统一身份认证。', 409);
  try {
    return apiSuccess(await createSchoolnetCaptcha(user.id, studentId));
  } catch (error) {
    if (error instanceof CampusAuthError) return apiError(error.message, error.status);
    return apiError('校园网验证码获取失败。', 503);
  }
}
