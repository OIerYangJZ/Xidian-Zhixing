import { getKnowledgeAdmin } from '@/lib/ai/admin';
import { knowledgeRequest, AiServiceError } from '@/lib/ai/rag';
import { apiError, apiSuccess } from '@/lib/apiResponse';

export async function GET() {
  if (!(await getKnowledgeAdmin())) return apiError('需要管理员权限。', 403);
  try {
    const [sources, status] = await Promise.all([
      knowledgeRequest<{ items: unknown[] }>('/documents'),
      knowledgeRequest<Record<string, unknown>>('/status'),
    ]);
    return apiSuccess({ items: sources.items, status });
  } catch (error) {
    const status = error instanceof AiServiceError && error.code === 'rag_not_configured' ? 503 : 502;
    return apiError('知识服务暂时不可用。', status);
  }
}

export async function POST(request: Request) {
  if (!(await getKnowledgeAdmin())) return apiError('需要管理员权限。', 403);
  const body = (await request.json().catch(() => null)) as Record<string, unknown> | null;
  const title = typeof body?.title === 'string' ? body.title.trim() : '';
  const content = typeof body?.content === 'string' ? body.content.trim() : '';
  const sourceUrl = typeof body?.sourceUrl === 'string' ? body.sourceUrl.trim() : '';
  if (!title || (!content && !sourceUrl)) return apiError('标题以及正文或来源链接不能为空。', 400);
  try {
    const result = await knowledgeRequest('/documents', {
      method: 'POST',
      body: JSON.stringify({ ...body, title, content: content || undefined, sourceUrl: sourceUrl || undefined }),
    });
    return apiSuccess(result, 201);
  } catch (error) {
    const status = error instanceof AiServiceError && error.code === 'rag_not_configured' ? 503 : 502;
    return apiError('知识文档写入失败。', status);
  }
}
