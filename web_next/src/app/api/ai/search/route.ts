import { AiServiceError, searchCampusKnowledge } from '@/lib/ai/rag';
import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';

export async function POST(request: Request) {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  const body = (await request.json().catch(() => null)) as { query?: unknown } | null;
  const query = typeof body?.query === 'string' ? body.query.trim() : '';
  if (!query || query.length > 2000) return apiError('检索内容不能为空，且最多 2000 字。', 400);

  try {
    const result = await searchCampusKnowledge(query, { includeCommunity: false });
    const items = result.items.map((item) => ({
      id: item.id,
      title: item.originalTitle || item.title,
      summary: item.summary || item.content.slice(0, 260),
      sourceUrl: item.originalSourceUrl || item.sourceUrl || '',
      authority: item.authority || '',
      score: item.score || 0,
    }));
    return apiSuccess({ items, citations: items, traceId: result.traceId });
  } catch (error) {
    if (error instanceof AiServiceError) {
      const status = error.code === 'rag_not_configured' ? 503 : 502;
      return apiError(
        error.code === 'rag_not_configured' ? '校园知识服务尚未配置。' : '校园知识检索暂时不可用。',
        status,
        { code: error.code },
      );
    }
    return apiError('校园知识检索暂时不可用。', 502);
  }
}
