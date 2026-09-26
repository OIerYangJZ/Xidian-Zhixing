import { AiServiceError, answerSelectedText } from '@/lib/ai/rag';
import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';

export async function POST(request: Request) {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  const body = (await request.json().catch(() => null)) as {
    selectedText?: unknown;
    content?: unknown;
    question?: unknown;
  } | null;
  const selectedText =
    typeof body?.selectedText === 'string'
      ? body.selectedText.trim()
      : typeof body?.content === 'string'
      ? body.content.trim()
      : '';
  const question =
    typeof body?.question === 'string' ? body.question.trim().slice(0, 300) : '解释这段内容并提取关键信息';
  if (!selectedText) return apiError('选中文本不能为空。', 400);
  if (selectedText.length > 11_000) return apiError('选中文本最多 11000 字，请分段处理。', 400);
  try {
    const result = await answerSelectedText(question, selectedText);
    return apiSuccess({
      answer: result.answer,
      reply: result.answer,
      citations: [],
      references: [],
      reviewStatus: 'approved',
    });
  } catch (error) {
    const status = error instanceof AiServiceError && error.code === 'ai_not_configured' ? 503 : 502;
    return apiError(status === 503 ? 'AI 模型服务尚未配置。' : 'AI 服务暂时不可用。', status);
  }
}
