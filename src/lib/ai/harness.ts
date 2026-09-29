import 'server-only';
import { randomUUID } from 'crypto';
import type { Prisma } from '@prisma/client';
import prisma from '@/lib/prisma/prisma';

export type AgentSource = {
  citation: number;
  title: string;
  source: string | null;
  documentId: string;
};

type ToolTrace = { tool: string; query?: string; file?: string | null; file_id?: string; matches?: number; title?: string };

type HarnessReply = {
  answer?: unknown;
  sources?: AgentSource[];
  toolTrace?: ToolTrace[];
  model?: string;
  provider?: string;
  durationMs?: number;
};

export class AgentHarnessError extends Error {
  constructor(readonly code: 'ai_not_configured' | 'corpus_not_configured' | 'harness_unavailable' | 'ai_upstream_error') {
    super(code);
  }
}

export async function answerWithAgentHarness(
  userId: string,
  conversationId: string,
  userMessageId: string,
  question: string,
  language: 'zh' | 'en' = 'zh',
) {
  const historyRows = await prisma.aiMessage.findMany({
    where: { conversationId, id: { not: userMessageId }, role: { in: ['USER', 'ASSISTANT'] } },
    orderBy: { createdAt: 'desc' },
    take: 16,
    select: { role: true, content: true },
  });
  const history = historyRows.reverse().map((message) => ({
    role: message.role === 'USER' ? 'user' : 'assistant',
    content: message.content,
  }));
  const traceId = randomUUID();
  const startedAt = Date.now();
  const harnessUrl = (process.env.AGENT_HARNESS_URL?.trim() || 'http://127.0.0.1:8002').replace(/\/+$/, '');

  let response: Response;
  try {
    response = await fetch(`${harnessUrl}/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question, language, history }),
      signal: AbortSignal.timeout(120_000),
    });
  } catch {
    throw new AgentHarnessError('harness_unavailable');
  }

  const payload = (await response.json().catch(() => null)) as
    | (HarnessReply & { detail?: { code?: string } })
    | null;
  if (!response.ok) {
    const code = payload?.detail?.code;
    if (code === 'ai_not_configured' || code === 'corpus_not_configured') {
      throw new AgentHarnessError(code);
    }
    throw new AgentHarnessError('ai_upstream_error');
  }
  if (!payload || typeof payload.answer !== 'string' || !payload.answer.trim()) {
    throw new AgentHarnessError('ai_upstream_error');
  }

  const sources = Array.isArray(payload.sources) ? payload.sources : [];
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
      },
    });
    await tx.aiTrace.create({
      data: {
        userId,
        provider,
        model,
        requestId: traceId,
        durationMs,
        metadata: {
          mode: 'pydantic_ai_file_tools',
          toolTrace: toolTrace as Prisma.InputJsonValue,
          sourceIds: sources.map((source) => source.documentId),
        },
      },
    });
    await tx.aiConversation.update({ where: { id: conversationId }, data: { updatedAt: new Date() } });
    return assistantMessage;
  });

  return { message, sources, traceId, toolTrace };
}
