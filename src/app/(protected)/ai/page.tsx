import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { AIChat, type AIConversationData } from './AIChat';

export const metadata = { title: '知行 AI' };

export default async function Page() {
  const [user] = await getServerUser();
  const conversations = user?.id
    ? await prisma.aiConversation.findMany({
        where: { userId: user.id },
        orderBy: { updatedAt: 'desc' },
        include: { messages: { orderBy: { createdAt: 'asc' }, take: 40 } },
      })
    : [];

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
      createdAt: message.createdAt.toISOString(),
    })),
  }));

  return <AIChat initialConversations={initialConversations} />;
}
