import { createXidianLoginAttempt } from '@/lib/auth/xidianCas';
import { apiError, apiSuccess } from '@/lib/apiResponse';

export async function POST(request: Request) {
  const body = (await request.json().catch(() => ({}))) as { callbackUrl?: unknown };
  try {
    return apiSuccess(await createXidianLoginAttempt(request, body.callbackUrl), 201);
  } catch {
    return apiError('学校统一认证暂时不可用。', 503, { code: 'xidian_auth_not_configured' });
  }
}
