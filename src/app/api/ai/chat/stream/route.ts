import { randomUUID } from 'crypto';
import type { Prisma } from '@prisma/client';
import { apiError } from '@/lib/apiResponse';
import { harnessErrorMessage } from '@/lib/ai/errors';
import { getServerUser } from '@/lib/getServerUser';
import { createAgentPrincipalToken } from '@/lib/ai/harnessPrincipal';
import { buildHarnessHistory, HISTORY_MAX_TURNS } from '@/lib/ai/harnessHistory';
import { harnessUIContext, validateUI } from '@/lib/ai/ui';
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
    uiVersion?: unknown;
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
    take: HISTORY_MAX_TURNS,
    select: { role: true, content: true, sources: true },
  });
  const { history, truncated: historyTruncated } = buildHarnessHistory(historyRows);

  const harnessUrl = (process.env.AGENT_HARNESS_URL?.trim() || 'http://127.0.0.1:8002').replace(/\/+$/, '');
  const traceId = randomUUID();
  const startedAt = Date.now();
  const abortController = new AbortController();
  let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
  let cancelled = false;
  let responseCancelled = false;
  const onAbort = () => {
    cancelled = true;
    abortController.abort();
    reader?.cancel().catch(() => undefined);
  };
  const timeout = setTimeout(() => {
    abortController.abort();
    reader?.cancel().catch(() => undefined);
  }, 150_000);
  const cleanup = () => {
    clearTimeout(timeout);
    request.signal.removeEventListener('abort', onAbort);
  };
  request.signal.addEventListener('abort', onAbort, { once: true });
  if (request.signal.aborted) onAbort();
  const recordFailure = async (
    code: string,
    agentEvents: HarnessEvent[] = [],
    usage: Record<string, unknown> = {},
    reason?: string,
  ) => {
    await prisma.$transaction(async (tx) => {
      await tx.aiMessage.deleteMany({ where: { id: userMessage.id } });
      await tx.aiTrace.create({
        data: {
          userId: user.id,
          provider: 'openai-compatible',
          model: process.env.AGENT_HARNESS_MODEL || 'deepseek-v4-flash',
          requestId: traceId,
          durationMs: Date.now() - startedAt,
          promptTokens: typeof usage.inputTokens === 'number' ? usage.inputTokens : undefined,
          completionTokens: typeof usage.outputTokens === 'number' ? usage.outputTokens : undefined,
          metadata: {
            mode: 'pydantic_ai_file_tools',
            conversationId: conversation!.id,
            userMessageId: userMessage.id,
            outcome: code,
            usage: usage as Prisma.InputJsonValue,
            agentEvents: agentEvents as Prisma.InputJsonValue,
            // Kept so a provider rejection stays diagnosable after the console output is gone.
            ...(reason ? { failureReason: reason } : {}),
          },
        },
      });
    });
  };
  let upstream: Response;
  try {
    upstream = await fetch(`${harnessUrl}/chat/stream`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        question,
        language: body?.language === 'en' ? 'en' : 'zh',
        history,
        principal_token: createAgentPrincipalToken(user.id),
        trace_id: traceId,
        ...harnessUIContext(body?.uiVersion),
      }),
      signal: abortController.signal,
    });
  } catch {
    cleanup();
    const code = abortController.signal.aborted && !cancelled ? 'ai_timeout' : 'harness_unavailable';
    await recordFailure(cancelled ? 'cancelled' : code);
    return apiError(
      code === 'ai_timeout'
        ? '本轮回答等待超过 150 秒，已中断。可以缩小问题范围，或换一轮更短的提问。'
        : 'AI Agent 服务暂时无法连接。',
      code === 'ai_timeout' ? 504 : 503,
      { code },
    );
  }

  if (!upstream.ok || !upstream.body) {
    const detail = (await upstream.json().catch(() => null)) as {
      detail?: { code?: string; usage?: Record<string, unknown>; reason?: string };
    } | null;
    const code = detail?.detail?.code || 'ai_upstream_error';
    cleanup();
    await recordFailure(code, [], detail?.detail?.usage, detail?.detail?.reason);
    const message = harnessErrorMessage(code, {
      status: upstream.status,
      reason: detail?.detail?.reason,
      usage: detail?.detail?.usage,
    });
    return apiError(message, upstream.status, { code });
  }

  const responseBody = new ReadableStream<Uint8Array>({
    async start(controller) {
      const decoder = new TextDecoder();
      reader = upstream.body!.getReader();
      const agentEvents: HarnessEvent[] = [];
      let pending = '';
      let completed = false;
      let failureCode: string | undefined;
      let failureUsage: Record<string, unknown> = {};
      let failureReason: string | undefined;
      const send = (event: HarnessEvent) => {
        if (!cancelled) controller.enqueue(encodeEvent(event));
      };

      try {
        if (cancelled) return;
        send({
          type: 'start',
          conversationId: conversation!.id,
          userMessage: {
            id: userMessage.id,
            role: userMessage.role,
            content: userMessage.content,
            sources: [],
            createdAt: userMessage.createdAt.toISOString(),
          },
          historyTruncated,
        });

        while (!cancelled) {
          // eslint-disable-next-line no-await-in-loop -- Read stream chunks in order and preserve backpressure.
          const { value, done } = await reader.read();
          if (done) break;
          pending += decoder.decode(value, { stream: true });
          if (pending.length > 1_000_000) throw new Error('Agent stream frame is too large');
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
              agentEvents.push(limitStoredEvent(event));
              send(event);
            } else if (event.type === 'error') {
              failureCode = typeof event.code === 'string' ? event.code : 'ai_upstream_error';
              failureUsage =
                event.usage && typeof event.usage === 'object' ? (event.usage as Record<string, unknown>) : {};
              failureReason = typeof event.reason === 'string' ? event.reason : undefined;
              send(event);
              break;
            } else if (event.type === 'complete') {
              const answer = typeof event.answer === 'string' ? event.answer : '';
              if (!answer.trim()) throw new Error('Agent returned an empty answer');
              const sources = Array.isArray(event.sources) ? event.sources : [];
              const presentation = validateUI(body?.uiVersion === 1 ? event.ui : null, sources);
              const usage =
                event.usage && typeof event.usage === 'object' ? (event.usage as Record<string, unknown>) : {};
              failureUsage = usage;
              // eslint-disable-next-line no-await-in-loop -- Commit the completed answer before sending done.
              const message = await prisma.$transaction(async (tx) => {
                const assistantMessage = await tx.aiMessage.create({
                  data: {
                    conversationId: conversation!.id,
                    role: 'ASSISTANT',
                    content: answer,
                    sources: sources as Prisma.InputJsonValue,
                    ...(presentation.ui ? { ui: presentation.ui as Prisma.InputJsonValue } : {}),
                  },
                });
                await tx.aiTrace.create({
                  data: {
                    userId: user.id,
                    provider: typeof event.provider === 'string' ? event.provider : 'deepseek',
                    model: typeof event.model === 'string' ? event.model : 'deepseek-v4-flash',
                    requestId: traceId,
                    durationMs: typeof event.durationMs === 'number' ? event.durationMs : undefined,
                    promptTokens: typeof usage.inputTokens === 'number' ? usage.inputTokens : undefined,
                    completionTokens: typeof usage.outputTokens === 'number' ? usage.outputTokens : undefined,
                    metadata: {
                      mode: 'pydantic_ai_file_tools',
                      outcome: 'complete',
                      usage: usage as Prisma.InputJsonValue,
                      conversationId: conversation!.id,
                      assistantMessageId: assistantMessage.id,
                      toolTrace: (Array.isArray(event.toolTrace) ? event.toolTrace : []) as Prisma.InputJsonValue,
                      agentEvents: agentEvents as Prisma.InputJsonValue,
                      historyTruncated,
                      uiCards: presentation.ui?.cards.length || 0,
                      uiErrors: [
                        ...(Array.isArray(event.uiErrors)
                          ? event.uiErrors.filter((item) => typeof item === 'string')
                          : []),
                        ...presentation.errors,
                      ],
                    },
                  },
                });
                await tx.aiConversation.update({
                  where: { id: conversation!.id },
                  data: { updatedAt: new Date() },
                });
                return assistantMessage;
              });
              completed = true;
              send({
                type: 'done',
                conversationId: conversation!.id,
                message: {
                  id: message.id,
                  role: message.role,
                  content: message.content,
                  sources,
                  ui: presentation.ui,
                  createdAt: message.createdAt.toISOString(),
                },
                traceId,
                durationMs: typeof event.durationMs === 'number' ? event.durationMs : undefined,
              });
              break;
            } else {
              send(event);
            }
            boundary = pending.indexOf('\n\n');
          }
          if (completed || failureCode) break;
        }
        if (!completed && !failureCode && !cancelled) {
          failureCode = abortController.signal.aborted ? 'ai_timeout' : 'ai_upstream_error';
          send({ type: 'error', code: failureCode, usage: failureUsage });
        }
      } catch {
        failureCode = abortController.signal.aborted && !cancelled ? 'ai_timeout' : 'ai_upstream_error';
        send({ type: 'error', code: failureCode, usage: failureUsage });
      } finally {
        cleanup();
        await reader.cancel().catch(() => undefined);
        reader.releaseLock();
        try {
          if (!completed)
            await recordFailure(
              cancelled ? 'cancelled' : failureCode || 'ai_upstream_error',
              agentEvents,
              failureUsage,
              failureReason,
            );
        } finally {
          if (!responseCancelled) controller.close();
        }
      }
    },
    cancel() {
      responseCancelled = true;
      onAbort();
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
