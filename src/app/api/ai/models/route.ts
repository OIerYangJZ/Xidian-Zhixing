import { apiError, apiSuccess } from '@/lib/apiResponse';

export async function GET() {
  const model = process.env.BACKEND_AI_MODEL?.trim();
  if (!process.env.BACKEND_AI_BASE_URL || !process.env.BACKEND_AI_API_KEY || !model) {
    return apiError('服务器尚未配置 AI 服务。', 503, { code: 'ai_not_configured' });
  }
  return apiSuccess({ models: [model], currentModel: model });
}
