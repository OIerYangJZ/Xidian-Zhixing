import 'server-only';
import { randomUUID } from 'crypto';
import type { Prisma } from '@prisma/client';
import { createAgentPrincipalToken } from '@/lib/ai/harnessPrincipal';
import { buildHarnessHistory, HISTORY_MAX_TURNS } from '@/lib/ai/harnessHistory';
import { harnessErrorMessage } from '@/lib/ai/errors';
import { harnessUIContext, validateUI } from '@/lib/ai/ui';
import prisma from '@/lib/prisma/prisma';

export type AgentSource = {
  citation: number;
  title: string;
  source: string | null;
  documentId: string;
};

type ToolTrace = {
  tool: string;
  query?: string;
  file?: string | null;
  file_id?: string;
  matches?: number;
  title?: string;
};

type HarnessReply = {
  answer?: unknown;
  sources?: AgentSource[];
  ui?: unknown;
  uiErrors?: unknown;
  toolTrace?: ToolTrace[];
  model?: string;
  provider?: string;
  durationMs?: number;
  usage?: { inputTokens?: number; outputTokens?: number; requests?: number; toolCalls?: number };
};

export class AgentHarnessError extends Error {
  constructor(
    readonly code:
      | 'ai_not_configured'
      | 'corpus_not_configured'
      | 'harness_unavailable'
      | 'ai_upstream_error'
      | 'ai_busy'
      | 'ai_timeout'
      | 'ai_budget_exceeded'
      | 'ai_request_invalid',
    /** How much of this turn's budget the harness spent before it failed. */
    readonly usage?: HarnessReply['usage'],
    /** The harness's own description of a rejected request, never shown raw to users. */
    readonly reason?: string,
  ) {
    super(code);
  }
}

export async function answerWithAgentHarness(
  userId: string,
  conversationId: string,
  userMessageId: string,
  question: string,
  language: 'zh' | 'en' = 'zh',
  signal?: AbortSignal,
  uiVersion?: 1,
) {
  const historyRows = await prisma.aiMessage.findMany({
    where: { conversationId, id: { not: userMessageId }, role: { in: ['USER', 'ASSISTANT'] } },
    orderBy: { createdAt: 'desc' },
    take: HISTORY_MAX_TURNS,
    select: { role: true, content: true, sources: true },
  });
  const { history, truncated: historyTruncated } = buildHarnessHistory(historyRows);
  const traceId = randomUUID();
  const startedAt = Date.now();
  const harnessUrl = (process.env.AGENT_HARNESS_URL?.trim() || 'http://127.0.0.1:8002').replace(/\/+$/, '');

  let response: Response;
  let usage: HarnessReply['usage'];
  const abortController = new AbortController();
  const onAbort = () => abortController.abort();
  signal?.addEventListener('abort', onAbort, { once: true });
  if (signal?.aborted) onAbort();
  const timeout = setTimeout(onAbort, 150_000);
  try {
    try {
      response = await fetch(`${harnessUrl}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          question,
          language,
          history,
          principal_token: createAgentPrincipalToken(userId),
          trace_id: traceId,
          ...harnessUIContext(uiVersion),
        }),
        signal: abortController.signal,
      });
    } catch {
      throw new AgentHarnessError(
        abortController.signal.aborted && !signal?.aborted ? 'ai_timeout' : 'harness_unavailable',
      );
    }

    const payload = (await response.json().catch(() => null)) as
      | (HarnessReply & { detail?: { code?: string; usage?: HarnessReply['usage']; reason?: string } })
      | null;
    usage = payload?.usage || payload?.detail?.usage;
    if (!payload && abortController.signal.aborted && !signal?.aborted) {
      throw new AgentHarnessError('ai_timeout');
    }
    if (!response.ok) {
      const code = payload?.detail?.code;
      if (
        code === 'ai_not_configured' ||
        code === 'corpus_not_configured' ||
        code === 'ai_busy' ||
        code === 'ai_timeout' ||
        code === 'ai_budget_exceeded' ||
        code === 'ai_request_invalid'
      ) {
        throw new AgentHarnessError(code, usage, payload?.detail?.reason);
      }
      throw new AgentHarnessError(
        'ai_upstream_error',
        usage,
        harnessErrorMessage('ai_upstream_error', {
          status: response.status,
        }),
      );
    }
    if (!payload || typeof payload.answer !== 'string' || !payload.answer.trim()) {
      throw new AgentHarnessError('ai_upstream_error', usage);
    }

    const sources = Array.isArray(payload.sources) ? payload.sources : [];
    const presentation = validateUI(uiVersion === 1 ? payload.ui : null, sources);
    const toolTrace = Array.isArray(payload.toolTrace) ? payload.toolTrace : [];
    const durationMs = Date.now() - startedAt;
    const model = payload.model || process.env.AGENT_HARNESS_MODEL || 'deepseek-v4-flash';
    const provider = payload.provider || 'deepseek';
    const message = await prisma.$transaction(async (tx) => {
      const assistantMessage = await tx.aiMessage.create({
        data: {
          conversationId,
          role: 'ASSISTANT',
          content: payload.answer as string,
          sources: sources as Prisma.InputJsonValue,
          ...(presentation.ui ? { ui: presentation.ui as Prisma.InputJsonValue } : {}),
        },
      });
      await tx.aiTrace.create({
        data: {
          userId,
          provider,
          model,
          requestId: traceId,
          durationMs,
          promptTokens: payload.usage?.inputTokens,
          completionTokens: payload.usage?.outputTokens,
          metadata: {
            mode: 'pydantic_ai_file_tools',
            outcome: 'complete',
            conversationId,
            assistantMessageId: assistantMessage.id,
            usage: (payload.usage || {}) as Prisma.InputJsonValue,
            toolTrace: toolTrace as Prisma.InputJsonValue,
            sourceIds: sources.map((source) => source.documentId),
            historyTruncated,
            uiCards: presentation.ui?.cards.length || 0,
            uiErrors: [
              ...(Array.isArray(payload.uiErrors) ? payload.uiErrors.filter((item) => typeof item === 'string') : []),
              ...presentation.errors,
            ],
          },
        },
      });
      await tx.aiConversation.update({ where: { id: conversationId }, data: { updatedAt: new Date() } });
      return assistantMessage;
    });

    return { message, sources, traceId, toolTrace };
  } catch (error) {
    await prisma.aiTrace.create({
      data: {
        userId,
        provider: 'openai-compatible',
        model: process.env.AGENT_HARNESS_MODEL || 'deepseek-v4-flash',
        requestId: traceId,
        durationMs: Date.now() - startedAt,
        promptTokens: usage?.inputTokens,
        completionTokens: usage?.outputTokens,
        metadata: {
          mode: 'pydantic_ai_file_tools',
          conversationId,
          userMessageId,
          usage: (usage || {}) as Prisma.InputJsonValue,
          historyTruncated,
          // The harness's own words about the failure. Without it a rejected provider call is only
          // ever recorded as `ai_upstream_error`, which names nothing an operator can act on.
          ...(error instanceof AgentHarnessError && error.reason ? { failureReason: error.reason } : {}),
          outcome: signal?.aborted
            ? 'cancelled'
            : error instanceof AgentHarnessError
            ? error.code
            : 'ai_upstream_error',
        },
      },
    });
    throw error;
  } finally {
    clearTimeout(timeout);
    signal?.removeEventListener('abort', onAbort);
  }
}
