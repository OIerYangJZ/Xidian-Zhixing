import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';
import { CampusAuthError, sendDormWaterSms } from '@/lib/campus/upstreamAuth';

export async function POST(request: Request) {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  const body = (await request.json().catch(() => null)) as {
    sessionId?: unknown;
    phone?: unknown;
    imageCode?: unknown;
  } | null;
  if (typeof body?.sessionId !== 'string' || typeof body.phone !== 'string' || typeof body.imageCode !== 'string') {
    return apiError('请填写手机号和图形验证码。', 400);
  }
  try {
    return apiSuccess(
      await sendDormWaterSms({
        userId: user.id,
        sessionId: body.sessionId,
        phone: body.phone,
        imageCode: body.imageCode,
      }),
    );
  } catch (error) {
    if (error instanceof CampusAuthError) return apiError(error.message, error.status);
    return apiError('宿舍水机短信发送失败。', 503);
  }
}
