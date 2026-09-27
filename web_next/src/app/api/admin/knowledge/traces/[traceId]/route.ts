import { getKnowledgeAdmin } from '@/lib/ai/admin';
import { AiServiceError, knowledgeRequest } from '@/lib/ai/rag';
import { apiError, apiSuccess } from '@/lib/apiResponse';

export async function GET(_request: Request, props: { params: Promise<{ traceId: string }> }) {
  const params = await props.params;
  if (!(await getKnowledgeAdmin())) return apiError('需要管理员权限。', 403);
  try {
    return apiSuccess(await knowledgeRequest(`/traces/${encodeURIComponent(params.traceId)}`));
  } catch (error) {
    const status = error instanceof AiServiceError && error.code === 'rag_not_configured' ? 503 : 502;
    return apiError('检索记录暂时不可用。', status);
  }
}
