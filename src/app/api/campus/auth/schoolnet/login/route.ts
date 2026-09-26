import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getXidianStudentId } from '@/lib/auth/xidianCas';
import { getServerUser } from '@/lib/getServerUser';
import { CampusAuthError, loginSchoolnet } from '@/lib/campus/upstreamAuth';

export async function POST(request: Request) {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  const studentId = await getXidianStudentId(user.id);
  if (!studentId) return apiError('请先完成西电统一身份认证。', 409);
  const body = (await request.json().catch(() => null)) as {
    attemptId?: unknown;
    password?: unknown;
    captcha?: unknown;
  } | null;
  if (typeof body?.attemptId !== 'string' || typeof body.password !== 'string' || typeof body.captcha !== 'string') {
    return apiError('请填写校园网密码和图形验证码。', 400);
  }
  try {
    return apiSuccess(
      await loginSchoolnet({
        userId: user.id,
        attemptId: body.attemptId,
        studentId,
        password: body.password,
        captcha: body.captcha,
      }),
    );
  } catch (error) {
    if (error instanceof CampusAuthError) return apiError(error.message, error.status);
    return apiError('校园网登录失败。', 503);
  }
}
