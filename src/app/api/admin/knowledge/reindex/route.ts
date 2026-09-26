import { getKnowledgeAdmin } from '@/lib/ai/admin';
import { AiServiceError, knowledgeRequest } from '@/lib/ai/rag';
import { apiError, apiSuccess } from '@/lib/apiResponse';

export async function POST() {
  if (!(await getKnowledgeAdmin())) return apiError('需要管理员权限。', 403);
  try {
    return apiSuccess(await knowledgeRequest('/reindex', { method: 'POST', body: '{}' }, 120_000));
  } catch (error) {
    const status = error instanceof AiServiceError && error.code === 'rag_not_configured' ? 503 : 502;
    return apiError('知识索引重建失败。', status);
  }
}
