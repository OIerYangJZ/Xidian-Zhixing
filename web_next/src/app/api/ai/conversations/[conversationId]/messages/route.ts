import { AiServiceError, answerWithCampusKnowledge } from '@/lib/ai/rag';
import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';

export async function GET(_request: Request, props: { params: Promise<{ conversationId: string }> }) {
  const params = await props.params;
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401, { code: 'unauthorized' });

  const conversation = await prisma.aiConversation.findFirst({
    where: { id: params.conversationId, userId: user.id },
    include: { messages: { orderBy: { createdAt: 'asc' } } },
  });
  if (!conversation) return apiError('没有找到这段对话。', 404, { code: 'not_found' });
  return apiSuccess(conversation.messages);
}

export async function POST(request: Request, props: { params: Promise<{ conversationId: string }> }) {
  const params = await props.params;
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401, { code: 'unauthorized' });

  const body = (await request.json().catch(() => null)) as { content?: unknown } | null;
  const content = typeof body?.content === 'string' ? body.content.trim() : '';
  if (!content || content.length > 12_000) {
    return apiError('问题不能为空，且最多 12000 字。', 400, { code: 'invalid_message' });
  }

  const conversation = await prisma.aiConversation.findFirst({
    where: { id: params.conversationId, userId: user.id },
    select: { id: true, title: true },
  });
  if (!conversation) return apiError('没有找到这段对话。', 404, { code: 'not_found' });

  const userMessage = await prisma.aiMessage.create({
    data: { conversationId: conversation.id, role: 'USER', content },
  });
  if (conversation.title === '新对话') {
    await prisma.aiConversation.update({
      where: { id: conversation.id },
      data: { title: content.slice(0, 32) },
    });
  }

  try {
    const result = await answerWithCampusKnowledge(user.id, conversation.id, content);
    return apiSuccess({ userMessage, ...result });
  } catch (error) {
    await prisma.aiMessage.delete({ where: { id: userMessage.id } });
    if (error instanceof AiServiceError) {
      const status = error.code.endsWith('not_configured') ? 503 : 502;
      const message =
        error.code === 'rag_not_configured'
          ? '校园知识服务尚未配置。'
          : error.code === 'ai_not_configured'
          ? 'AI 模型服务尚未配置。'
          : 'AI 服务暂时不可用。';
      return apiError(message, status, { code: error.code });
    }
    return apiError('AI 服务暂时不可用。', 502, { code: 'ai_upstream_error' });
  }
}
