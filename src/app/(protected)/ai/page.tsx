import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { AIChat, type AIConversationData, type AgentTraceEvent } from './AIChat';

export async function generateMetadata() {
  return { title: (await getInterfaceLanguage()) === 'en' ? 'Zhixing AI' : '知行 AI' };
}

export default async function Page() {
  const [user] = await getServerUser();
  const conversations = user?.id
    ? await prisma.aiConversation.findMany({
        where: { userId: user.id },
        orderBy: { updatedAt: 'desc' },
        include: { messages: { orderBy: { createdAt: 'asc' }, take: 40 } },
      })
    : [];
  const traces = user?.id
    ? await prisma.aiTrace.findMany({
        where: { userId: user.id },
        orderBy: { createdAt: 'desc' },
        take: 120,
        select: { metadata: true, durationMs: true },
      })
    : [];
  const traceByMessageId = new Map<string, { trace: AgentTraceEvent[]; summary?: string; durationMs?: number }>();
  for (const record of traces) {
    if (!record.metadata || typeof record.metadata !== 'object' || Array.isArray(record.metadata)) continue;
    const metadata = record.metadata as Record<string, unknown>;
    if (metadata.mode !== 'pydantic_ai_file_tools' || typeof metadata.assistantMessageId !== 'string') continue;
    traceByMessageId.set(metadata.assistantMessageId, {
      trace: Array.isArray(metadata.agentEvents) ? (metadata.agentEvents as AgentTraceEvent[]) : [],
      summary: typeof metadata.summary === 'string' ? metadata.summary : undefined,
      durationMs: record.durationMs ?? undefined,
    });
  }

  const initialConversations: AIConversationData[] = conversations.map((conversation) => ({
    id: conversation.id,
    title: conversation.title,
    updatedAt: conversation.updatedAt.toISOString(),
    messages: conversation.messages.map((message) => ({
      id: message.id,
      role: message.role,
      content: message.content,
      sources: Array.isArray(message.sources)
        ? (message.sources as unknown as AIConversationData['messages'][number]['sources'])
        : [],
      trace: traceByMessageId.get(message.id)?.trace,
      summary: traceByMessageId.get(message.id)?.summary,
      durationMs: traceByMessageId.get(message.id)?.durationMs,
      createdAt: message.createdAt.toISOString(),
    })),
  }));

  return <AIChat initialConversations={initialConversations} />;
}
