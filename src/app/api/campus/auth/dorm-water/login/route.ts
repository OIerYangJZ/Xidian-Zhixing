import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';
import { CampusAuthError, loginDormWater } from '@/lib/campus/upstreamAuth';

export async function POST(request: Request) {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  const body = (await request.json().catch(() => null)) as {
    sessionId?: unknown;
    phone?: unknown;
    smsCode?: unknown;
  } | null;
  if (typeof body?.sessionId !== 'string' || typeof body.phone !== 'string' || typeof body.smsCode !== 'string') {
    return apiError('请填写手机号和短信验证码。', 400);
  }
  try {
    return apiSuccess(
      await loginDormWater({ userId: user.id, sessionId: body.sessionId, phone: body.phone, smsCode: body.smsCode }),
    );
  } catch (error) {
    if (error instanceof CampusAuthError) return apiError(error.message, error.status);
    return apiError('宿舍水机登录失败。', 503);
  }
}
