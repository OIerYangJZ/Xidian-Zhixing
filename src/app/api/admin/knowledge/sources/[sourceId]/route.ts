import { getKnowledgeAdmin } from '@/lib/ai/admin';
import { knowledgeRequest, AiServiceError } from '@/lib/ai/rag';
import { apiError, apiSuccess } from '@/lib/apiResponse';

type RouteContext = { params: { sourceId: string } };

export async function PATCH(request: Request, { params }: RouteContext) {
  if (!(await getKnowledgeAdmin())) return apiError('需要管理员权限。', 403);
  const body = (await request.json().catch(() => null)) as Record<string, unknown> | null;
  try {
    const current = await knowledgeRequest<Record<string, unknown>>(
      `/documents/${encodeURIComponent(params.sourceId)}`,
    );
    const next: Record<string, unknown> = { ...current, ...(body || {}), id: params.sourceId };
    if (typeof next.title !== 'string' || typeof next.content !== 'string') {
      return apiError('文档标题和正文不能为空。', 400);
    }
    const result = await knowledgeRequest('/documents', { method: 'POST', body: JSON.stringify(next) });
    return apiSuccess(result);
  } catch (error) {
    const status = error instanceof AiServiceError && error.code === 'rag_not_configured' ? 503 : 502;
    return apiError('知识文档更新失败。', status);
  }
}

export async function DELETE(_request: Request, { params }: RouteContext) {
  if (!(await getKnowledgeAdmin())) return apiError('需要管理员权限。', 403);
  try {
    const result = await knowledgeRequest('/documents/status', {
      method: 'POST',
      body: JSON.stringify({ id: params.sourceId, status: 'archived' }),
    });
    return apiSuccess(result);
  } catch (error) {
    const status = error instanceof AiServiceError && error.code === 'rag_not_configured' ? 503 : 502;
    return apiError('知识文档归档失败。', status);
  }
}
