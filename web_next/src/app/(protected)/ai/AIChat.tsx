'use client';

import { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';

type AISource = { citation: number; title: string; source: string | null; documentId: string };
type AIMessageData = {
  id: string;
  role: 'USER' | 'ASSISTANT' | 'SYSTEM';
  content: string;
  sources: AISource[];
  createdAt: string;
};
export type AIConversationData = {
  id: string;
  title: string;
  updatedAt: string;
  messages: AIMessageData[];
};

export function AIChat({ initialConversations }: { initialConversations: AIConversationData[] }) {
  const { t, language } = useLanguage();
  const starterQuestions =
    language === 'zh'
      ? ['本周有哪些校园活动？', '如何申请加入一个社团？', '图书馆借阅规则是什么？']
      : [
          'What campus events are happening this week?',
          'How can I join a student club?',
          'What are the library borrowing rules?',
        ];
  const [conversations, setConversations] = useState(initialConversations);
  const [activeId, setActiveId] = useState(initialConversations[0]?.id || '');
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const activeConversation = useMemo(
    () => conversations.find((conversation) => conversation.id === activeId),
    [activeId, conversations],
  );

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ block: 'end' });
  }, [activeId, activeConversation?.messages.length, sending]);

  async function createConversation() {
    setError('');
    const response = await fetch('/api/ai/conversations', { method: 'POST' });
    if (!response.ok) {
      setError(t('暂时无法创建新对话。', 'Could not start a new conversation.'));
      return;
    }
    const conversation = (await response.json()) as Omit<AIConversationData, 'messages'>;
    const nextConversation = { ...conversation, messages: [] };
    setConversations((items) => [nextConversation, ...items]);
    setActiveId(nextConversation.id);
  }

  async function sendMessage(event?: FormEvent<HTMLFormElement>, prompt = draft) {
    event?.preventDefault();
    const content = prompt.trim();
    if (!content || sending) return;
    setError('');
    setSending(true);

    let conversationId = activeId;
    if (!conversationId) {
      const response = await fetch('/api/ai/conversations', { method: 'POST' });
      if (!response.ok) {
        setSending(false);
        setError(t('暂时无法创建新对话。', 'Could not start a new conversation.'));
        return;
      }
      const conversation = (await response.json()) as Omit<AIConversationData, 'messages'>;
      conversationId = conversation.id;
      setActiveId(conversationId);
      setConversations((items) => [{ ...conversation, messages: [] }, ...items]);
    }

    setDraft('');
    const response = await fetch('/api/ai/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content, conversationId: conversationId || undefined, language }),
    });
    setSending(false);

    if (!response.ok) {
      const result = (await response.json().catch(() => ({}))) as { data?: { code?: string }; message?: string };
      setError(
        result.data?.code === 'rag_not_configured'
          ? t('校园知识服务尚未配置。', 'Campus knowledge service is not configured.')
          : result.data?.code === 'ai_not_configured'
          ? t('AI 模型服务尚未配置。', 'AI model service is not configured.')
          : result.message || t('回答暂时没有生成，请稍后再试。', 'No answer was generated. Please try again.'),
      );
      setDraft(content);
      return;
    }

    const envelope = (await response.json()) as {
      data: { conversationId: string; userMessage: AIMessageData; message: AIMessageData };
    };
    const result = envelope.data;
    setConversations((items) =>
      items.some((conversation) => conversation.id === result.conversationId)
        ? items.map((conversation) =>
            conversation.id === result.conversationId
              ? {
                  ...conversation,
                  title: conversation.title === '新对话' ? content.slice(0, 32) : conversation.title,
                  updatedAt: result.message.createdAt,
                  messages: [...conversation.messages, result.userMessage, result.message],
                }
              : conversation,
          )
        : [
            {
              id: result.conversationId,
              title: content.slice(0, 32),
              updatedAt: result.message.createdAt,
              messages: [result.userMessage, result.message],
            },
            ...items,
          ],
    );
    setActiveId(result.conversationId);
  }

  return (
    <main className="flex h-[calc(100dvh-7.5rem-env(safe-area-inset-bottom))] min-h-0 flex-col md:h-dvh">
      <PageHeader
        title={t('知行 AI', 'Zhixing AI')}
        sticky
        action={
          <button
            type="button"
            onClick={createConversation}
            className="shrink-0 rounded-full bg-secondary px-4 py-2 text-sm font-medium transition hover:bg-secondary-accent">
            {t('新对话', 'New chat')}
          </button>
        }
      />

      <div className="flex gap-2 overflow-x-auto border-b border-border/80 px-4 py-3 sm:px-5">
        {conversations.map((conversation) => (
          <button
            key={conversation.id}
            type="button"
            onClick={() => setActiveId(conversation.id)}
            className={`max-w-48 shrink-0 truncate rounded-full px-3.5 py-2 text-xs transition ${
              activeId === conversation.id
                ? 'bg-primary text-primary-foreground'
                : 'bg-secondary text-secondary-foreground'
            }`}>
            {conversation.title}
          </button>
        ))}
      </div>

      <section className="min-h-0 flex-1 overflow-y-auto px-4 py-5 sm:px-6" aria-live="polite">
        {activeConversation?.messages.length ? (
          <div className="mx-auto flex max-w-2xl flex-col gap-5">
            {activeConversation.messages.map((message) => (
              <article
                key={message.id}
                className={message.role === 'USER' ? 'ml-auto max-w-[88%]' : 'mr-auto max-w-[92%]'}>
                <p className="mb-1 text-xs text-muted-foreground">
                  {message.role === 'USER' ? t('你', 'You') : t('知行助手', 'Zhixing assistant')}
                </p>
                <div
                  className={`whitespace-pre-wrap break-words rounded-lg px-4 py-3 text-sm leading-7 ${
                    message.role === 'USER' ? 'bg-primary text-primary-foreground' : 'bg-secondary/70 text-foreground'
                  }`}>
                  {message.content}
                </div>
                {message.sources.length > 0 && (
                  <div className="mt-2 flex flex-wrap gap-2">
                    {message.sources.map((source) => (
                      <span
                        key={`${message.id}-${source.citation}`}
                        className="rounded-full border border-border px-2.5 py-1 text-xs text-muted-foreground">
                        [{source.citation}] {source.title}
                      </span>
                    ))}
                  </div>
                )}
              </article>
            ))}
            {sending && (
              <p className="text-sm text-muted-foreground">
                {t('正在整理校园资料…', 'Looking through campus information…')}
              </p>
            )}
            <div ref={messagesEndRef} />
          </div>
        ) : (
          <div className="mx-auto flex h-full min-h-64 max-w-xl flex-col items-center justify-center text-center">
            <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-lg bg-primary/10 text-2xl text-primary">
              {t('知', 'Z')}
            </div>
            <div className="flex flex-wrap justify-center gap-2">
              {starterQuestions.map((question) => (
                <button
                  key={question}
                  type="button"
                  onClick={() => sendMessage(undefined, question)}
                  disabled={sending}
                  className="rounded-full border border-border px-3 py-2 text-xs transition hover:border-primary/50 hover:bg-primary/5 disabled:opacity-50">
                  {question}
                </button>
              ))}
            </div>
          </div>
        )}
      </section>

      {error && (
        <p role="alert" className="mt-3 text-sm text-destructive-foreground">
          {error}
        </p>
      )}
      <form onSubmit={sendMessage} className="mt-4 flex items-end gap-2 rounded-lg border border-border bg-card p-2">
        <label className="sr-only" htmlFor="campus-ai-prompt">
          {t('输入校园问题', 'Ask a campus question')}
        </label>
        <textarea
          id="campus-ai-prompt"
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter' && !event.shiftKey) {
              event.preventDefault();
              sendMessage();
            }
          }}
          rows={1}
          maxLength={4000}
          placeholder={t('问问校园里的事…', 'Ask about campus life…')}
          className="max-h-32 min-h-11 flex-1 resize-y bg-transparent px-3 py-3 text-sm outline-none placeholder:text-muted-foreground"
        />
        <button
          type="submit"
          disabled={sending || !draft.trim()}
          className="rounded-md bg-primary px-4 py-3 text-sm font-medium text-primary-foreground transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50">
          {t('发送', 'Send')}
        </button>
      </form>
      <p className="mt-2 text-center text-xs text-muted-foreground">
        {t(
          'AI 生成内容仅供参考，请以学校正式通知为准。',
          'AI responses are for reference. Follow official university notices.',
        )}
      </p>
    </main>
  );
}
