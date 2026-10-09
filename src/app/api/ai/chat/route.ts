import { AgentHarnessError, answerWithAgentHarness } from '@/lib/ai/harness';
import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';

export async function POST(request: Request) {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  const body = (await request.json().catch(() => null)) as {
    content?: unknown;
    question?: unknown;
    conversationId?: unknown;
    language?: unknown;
    uiVersion?: unknown;
  } | null;
  const question =
    typeof body?.content === 'string'
      ? body.content.trim()
      : typeof body?.question === 'string'
      ? body.question.trim()
      : '';
  if (!question || question.length > 12_000) return apiError('问题不能为空，且最多 12000 字。', 400);

  let conversation =
    typeof body?.conversationId === 'string'
      ? await prisma.aiConversation.findFirst({
          where: { id: body.conversationId, userId: user.id },
          select: { id: true, title: true },
        })
      : null;
  if (body?.conversationId && !conversation) return apiError('没有找到这段对话。', 404);
  if (!conversation) {
    conversation = await prisma.aiConversation.create({
      data: { userId: user.id, title: question.slice(0, 32) },
      select: { id: true, title: true },
    });
  }

  const userMessage = await prisma.aiMessage.create({
    data: { conversationId: conversation.id, role: 'USER', content: question },
  });
  if (conversation.title === '新对话') {
    await prisma.aiConversation.update({ where: { id: conversation.id }, data: { title: question.slice(0, 32) } });
  }

  try {
    const result = await answerWithAgentHarness(
      user.id,
      conversation.id,
      userMessage.id,
      question,
      body?.language === 'en' ? 'en' : 'zh',
      request.signal,
      body?.uiVersion === 1 ? 1 : undefined,
    );
    return apiSuccess({
      conversationId: conversation.id,
      userMessage: { ...userMessage, sources: [] },
      answer: result.message.content,
      reply: result.message.content,
      message: result.message,
      citations: result.sources,
      references: result.sources,
      traceId: result.traceId,
    });
  } catch (error) {
    await prisma.aiMessage.delete({ where: { id: userMessage.id } });
    if (error instanceof AgentHarnessError) {
      const status =
        error.code === 'ai_busy' || error.code === 'ai_budget_exceeded'
          ? 429
          : error.code === 'ai_timeout'
          ? 504
          : error.code.endsWith('not_configured')
          ? 503
          : 502;
      const message =
        error.code === 'ai_busy'
          ? 'AI 服务繁忙，请稍后重试。'
          : error.code === 'ai_timeout'
          ? '本轮回答超时，请缩小问题范围后重试。'
          : error.code === 'ai_budget_exceeded'
          ? '本轮检索已达到上限，请缩小问题范围后重试。'
          : error.code === 'corpus_not_configured'
          ? '本地校园资料库尚未配置。'
          : error.code === 'ai_not_configured'
          ? 'DeepSeek API 尚未配置。'
          : error.code === 'harness_unavailable'
          ? 'AI Agent 服务暂时无法连接。'
          : 'DeepSeek 服务暂时不可用。';
      return apiError(message, status, { code: error.code });
    }
    return apiError('AI 服务暂时不可用。', 502);
  }
}
