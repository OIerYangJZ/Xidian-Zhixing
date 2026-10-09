import { apiError, apiSuccess } from '@/lib/apiResponse';

export async function GET() {
  const explicitBaseUrl = process.env.AGENT_HARNESS_BASE_URL?.trim();
  const legacyBaseUrl = process.env.BACKEND_AI_BASE_URL?.trim();
  const legacyIsDeepSeek = legacyBaseUrl && new URL(legacyBaseUrl).hostname === 'api.deepseek.com';
  const model =
    process.env.AGENT_HARNESS_MODEL?.trim() ||
    (legacyIsDeepSeek ? process.env.BACKEND_AI_MODEL?.trim() : '') ||
    'deepseek-v4-flash';
  const key =
    process.env.AGENT_HARNESS_API_KEY ||
    process.env.DEEPSEEK_API_KEY ||
    ((explicitBaseUrl && new URL(explicitBaseUrl).hostname === 'api.deepseek.com') || legacyIsDeepSeek
      ? process.env.BACKEND_AI_API_KEY
      : undefined);
  if (!key) {
    return apiError('服务器尚未配置 DeepSeek API。', 503, { code: 'ai_not_configured' });
  }
  return apiSuccess({ models: [model], currentModel: model });
}
