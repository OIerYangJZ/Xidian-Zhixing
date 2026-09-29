import { randomUUID } from 'crypto';
import type { Prisma } from '@prisma/client';
import { apiError } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';

type HarnessEvent = {
  type: string;
  [key: string]: unknown;
};

function encodeEvent(event: HarnessEvent) {
  return new TextEncoder().encode(`data: ${JSON.stringify(event)}\n\n`);
}

function parseFrame(frame: string): HarnessEvent | null {
  const data = frame
    .split(/\r?\n/)
    .find((line) => line.startsWith('data:'))
    ?.slice(5)
    .trim();
  if (!data) return null;
  try {
    return JSON.parse(data) as HarnessEvent;
  } catch {
    return null;
  }
}

function limitStoredEvent(event: HarnessEvent): HarnessEvent {
  if (event.type !== 'tool_result') return event;
  const serialized = JSON.stringify(event.result) || '';
  if (serialized.length <= 3_000) return event;
  return { ...event, result: `${serialized.slice(0, 3_000)}…[历史轨迹已截断；本轮展开内容完整]` };
}

export async function POST(request: Request) {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);

  const body = (await request.json().catch(() => null)) as {
    content?: unknown;
    conversationId?: unknown;
    language?: unknown;
  } | null;
  const question = typeof body?.content === 'string' ? body.content.trim() : '';
  if (!question || question.length > 12_000) {
    return apiError('问题不能为空，且最多 12000 字。', 400);
  }

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
    await prisma.aiConversation.update({
      where: { id: conversation.id },
      data: { title: question.slice(0, 32) },
    });
  }

  const historyRows = await prisma.aiMessage.findMany({
    where: { conversationId: conversation.id, id: { not: userMessage.id }, role: { in: ['USER', 'ASSISTANT'] } },
    orderBy: { createdAt: 'desc' },
    take: 16,
    select: { role: true, content: true },
  });
  const history = historyRows.reverse().map((message) => ({
    role: message.role === 'USER' ? 'user' : 'assistant',
    content: message.content,
  }));

  const harnessUrl = (process.env.AGENT_HARNESS_URL?.trim() || 'http://127.0.0.1:8002').replace(/\/+$/, '');
  let upstream: Response;
  try {
    upstream = await fetch(`${harnessUrl}/chat/stream`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        question,
        language: body?.language === 'en' ? 'en' : 'zh',
        history,
      }),
      signal: AbortSignal.timeout(300_000),
    });
  } catch {
    await prisma.aiMessage.delete({ where: { id: userMessage.id } });
    return apiError('AI Agent 服务暂时无法连接。', 503, { code: 'harness_unavailable' });
  }

  if (!upstream.ok || !upstream.body) {
    const detail = (await upstream.json().catch(() => null)) as { detail?: { code?: string } } | null;
    await prisma.aiMessage.delete({ where: { id: userMessage.id } });
    const code = detail?.detail?.code || 'ai_upstream_error';
    const message =
      code === 'corpus_not_configured'
        ? '本地校园资料库尚未配置。'
        : code === 'ai_not_configured'
        ? 'DeepSeek API 尚未配置。'
        : 'AI Agent 服务暂时不可用。';
    return apiError(message, upstream.status, { code });
  }

  const traceId = randomUUID();
  const responseBody = new ReadableStream<Uint8Array>({
    async start(controller) {
      const decoder = new TextDecoder();
      const reader = upstream.body!.getReader();
      const agentEvents: HarnessEvent[] = [];
      let pending = '';
      let completed = false;
      let upstreamFailed = false;

      controller.enqueue(
        encodeEvent({
          type: 'start',
          conversationId: conversation!.id,
          userMessage: {
            id: userMessage.id,
            role: userMessage.role,
            content: userMessage.content,
            sources: [],
            createdAt: userMessage.createdAt.toISOString(),
          },
        }),
      );

      try {
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          pending += decoder.decode(value, { stream: true });
          let boundary = pending.indexOf('\n\n');
          while (boundary >= 0) {
            const frame = pending.slice(0, boundary);
            pending = pending.slice(boundary + 2);
            const event = parseFrame(frame);
            if (!event) {
              boundary = pending.indexOf('\n\n');
              continue;
            }

            if (event.type === 'tool_call' || event.type === 'tool_result') {
              agentEvents.push(event);
              controller.enqueue(encodeEvent(event));
            } else if (event.type === 'error') {
              upstreamFailed = true;
              controller.enqueue(encodeEvent(event));
            } else if (event.type === 'complete') {
              const answer = typeof event.answer === 'string' ? event.answer : '';
              if (!answer.trim()) throw new Error('Agent returned an empty answer');
              const sources = Array.isArray(event.sources) ? event.sources : [];
              const message = await prisma.$transaction(async (tx) => {
                const assistantMessage = await tx.aiMessage.create({
                  data: {
                    conversationId: conversation!.id,
                    role: 'ASSISTANT',
                    content: answer,
                    sources: sources as Prisma.InputJsonValue,
                  },
                });
                await tx.aiTrace.create({
                  data: {
                    userId: user.id,
                    provider: typeof event.provider === 'string' ? event.provider : 'deepseek',
                    model: typeof event.model === 'string' ? event.model : 'deepseek-v4-flash',
                    requestId: traceId,
                    durationMs: typeof event.durationMs === 'number' ? event.durationMs : undefined,
                    metadata: {
                      mode: 'pydantic_ai_file_tools',
                      conversationId: conversation!.id,
                      assistantMessageId: assistantMessage.id,
                      summary: typeof event.summary === 'string' ? event.summary : '',
                      toolTrace: (Array.isArray(event.toolTrace) ? event.toolTrace : []) as Prisma.InputJsonValue,
                      agentEvents: agentEvents.map(limitStoredEvent) as Prisma.InputJsonValue,
                    },
                  },
                });
                await tx.aiConversation.update({
                  where: { id: conversation!.id },
                  data: { updatedAt: new Date() },
                });
                return assistantMessage;
              });
              controller.enqueue(
                encodeEvent({
                  type: 'done',
                  conversationId: conversation!.id,
                  message: {
                    id: message.id,
                    role: message.role,
                    content: message.content,
                    sources,
                    createdAt: message.createdAt.toISOString(),
                  },
                  traceId,
                  summary: event.summary,
                  durationMs: typeof event.durationMs === 'number' ? event.durationMs : undefined,
                }),
              );
              completed = true;
              break;
            } else {
              controller.enqueue(encodeEvent(event));
            }
            boundary = pending.indexOf('\n\n');
          }
          if (completed) break;
        }
        if (!completed && !upstreamFailed) {
          controller.enqueue(encodeEvent({ type: 'error', code: 'ai_upstream_error' }));
        }
      } catch {
        controller.enqueue(encodeEvent({ type: 'error', code: 'ai_upstream_error' }));
      } finally {
        reader.releaseLock();
        controller.close();
      }
    },
  });

  return new Response(responseBody, {
    headers: {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    },
  });
}
