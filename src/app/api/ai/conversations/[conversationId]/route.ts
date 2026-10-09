import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';

type RouteContext = { params: Promise<{ conversationId: string }> };

/**
 * Permanently remove one conversation with its messages.
 *
 * `AiMessage.conversation` and `AiConversation.user` are both `onDelete: Restrict`, so the rows
 * have to go in dependency order inside one transaction. Traces carry the conversation id inside
 * `metadata` rather than in a column, so they are matched on that field and deleted too: they
 * hold the tool calls and token counts of the removed turns.
 */
export async function DELETE(_request: Request, props: RouteContext) {
  const params = await props.params;
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401, { code: 'unauthorized' });

  const conversation = await prisma.aiConversation.findFirst({
    where: { id: params.conversationId, userId: user.id },
    select: { id: true },
  });
  if (!conversation) return apiError('没有找到这段对话。', 404, { code: 'not_found' });

  const deleted = await prisma.$transaction(async (tx) => {
    const traces = await tx.aiTrace.deleteMany({
      where: { userId: user.id, metadata: { path: ['conversationId'], equals: conversation.id } },
    });
    const messages = await tx.aiMessage.deleteMany({ where: { conversationId: conversation.id } });
    await tx.aiConversation.delete({ where: { id: conversation.id } });
    return { messages: messages.count, traces: traces.count };
  });

  return apiSuccess({ id: conversation.id, deletedMessages: deleted.messages, deletedTraces: deleted.traces });
}

/** Rename a conversation; the title is the only mutable field a user owns today. */
export async function PATCH(request: Request, props: RouteContext) {
  const params = await props.params;
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401, { code: 'unauthorized' });

  const body = (await request.json().catch(() => null)) as { title?: unknown } | null;
  const title = typeof body?.title === 'string' ? body.title.trim().slice(0, 60) : '';
  if (!title) return apiError('标题不能为空。', 400, { code: 'invalid_title' });

  const conversation = await prisma.aiConversation.findFirst({
    where: { id: params.conversationId, userId: user.id },
    select: { id: true },
  });
  if (!conversation) return apiError('没有找到这段对话。', 404, { code: 'not_found' });

  const updated = await prisma.aiConversation.update({
    where: { id: conversation.id },
    data: { title },
    select: { id: true, title: true },
  });
  return apiSuccess(updated);
}
