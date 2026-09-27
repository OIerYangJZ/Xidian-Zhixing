'use client';

import { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';
import { useSession } from '@/lib/backend/session';
import { ApiError } from '@/lib/backend/client';
import { askAi, cancelAi, type AiCitation } from '@/lib/backend/endpoints';
import { postHref } from '@/lib/profileHref';

type AIMessageData = {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  sources: AiCitation[];
  createdAt: string;
};
export type AIConversationData = {
  id: string;
  title: string;
  updatedAt: string;
  messages: AIMessageData[];
};

/** The server keeps no chat history, so conversations stay in this browser. */
const MAX_STORED_CONVERSATIONS = 30;
const HISTORY_TURNS = 8;
const storageKey = (userId: string) => `zhixing-ai-conversations:${userId}`;

function loadConversations(userId: string): AIConversationData[] {
  try {
    const raw = window.localStorage.getItem(storageKey(userId));
    return raw ? (JSON.parse(raw) as AIConversationData[]) : [];
  } catch {
    return [];
  }
}

function newId() {
  return Array.from(crypto.getRandomValues(new Uint8Array(16)), (b) => b.toString(16).padStart(2, '0')).join('');
}

function citationHref(source: AiCitation): string | null {
  if (source.targetType === 'post' && source.targetId) return postHref(source.targetId);
  return source.sourceUrl || source.jumpUrl || null;
}

export function AIChat() {
  const { t, language } = useLanguage();
  const { data: session } = useSession();
  const userId = session?.user.id || '';
  const starterQuestions =
    language === 'zh'
      ? ['本周有哪些校园活动？', '如何申请加入一个社团？', '图书馆借阅规则是什么？']
      : [
          'What campus events are happening this week?',
          'How can I join a student club?',
          'What are the library borrowing rules?',
        ];
  const [conversations, setConversations] = useState<AIConversationData[]>([]);
  const [activeId, setActiveId] = useState('');
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const requestIdRef = useRef('');
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const activeConversation = useMemo(
    () => conversations.find((conversation) => conversation.id === activeId),
    [activeId, conversations],
  );

  useEffect(() => {
    if (!userId) return;
    const stored = loadConversations(userId);
    setConversations(stored);
    setActiveId(stored[0]?.id || '');
  }, [userId]);

  useEffect(() => {
    if (!userId) return;
    try {
      window.localStorage.setItem(storageKey(userId), JSON.stringify(conversations.slice(0, MAX_STORED_CONVERSATIONS)));
    } catch {
      // Storage full or disabled: the chat still works for this visit.
    }
  }, [conversations, userId]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ block: 'end' });
  }, [activeId, activeConversation?.messages.length, sending]);

  function createConversation() {
    setError('');
    setActiveId('');
  }

  const appendMessages = (conversationId: string, title: string, messages: AIMessageData[]) =>
    setConversations((items) => {
      const existing = items.find((item) => item.id === conversationId);
      const updated: AIConversationData = existing
        ? { ...existing, updatedAt: new Date().toISOString(), messages: [...existing.messages, ...messages] }
        : { id: conversationId, title, updatedAt: new Date().toISOString(), messages };
      return [updated, ...items.filter((item) => item.id !== conversationId)];
    });

  async function stop() {
    if (requestIdRef.current) await cancelAi(requestIdRef.current).catch(() => undefined);
  }

  async function sendMessage(event?: FormEvent<HTMLFormElement>, prompt = draft) {
    event?.preventDefault();
    const content = prompt.trim();
    if (!content || sending) return;
    setError('');
    setSending(true);

    const conversationId = activeId || newId();
    const history = (conversations.find((item) => item.id === conversationId)?.messages ?? [])
      .slice(-HISTORY_TURNS * 2)
      .map(({ role, content: text }) => ({ role, content: text }));
    const userMessage: AIMessageData = {
      id: newId(),
      role: 'user',
      content,
      sources: [],
      createdAt: new Date().toISOString(),
    };
    appendMessages(conversationId, content.slice(0, 32), [userMessage]);
    setActiveId(conversationId);
    setDraft('');

    const requestId = newId();
    requestIdRef.current = requestId;
    try {
      const result = await askAi(content, history, requestId);
      appendMessages(conversationId, content.slice(0, 32), [
        {
          id: result.traceId || newId(),
          role: 'assistant',
          content: result.answer,
          sources: result.citations || [],
          createdAt: new Date().toISOString(),
        },
      ]);
    } catch (cause) {
      const cancelled = cause instanceof ApiError && (cause.data as { cancelled?: boolean } | undefined)?.cancelled;
      if (!cancelled)
        setError(
          cause instanceof ApiError && cause.status === 503
            ? t('AI 服务暂未开放。', 'The AI service is not available yet.')
            : cause instanceof ApiError
            ? cause.message
            : t('回答暂时没有生成，请稍后再试。', 'No answer was generated. Please try again.'),
        );
    } finally {
      requestIdRef.current = '';
      setSending(false);
    }
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
                className={message.role === 'user' ? 'ml-auto max-w-[88%]' : 'mr-auto max-w-[92%]'}>
                <p className="mb-1 text-xs text-muted-foreground">
                  {message.role === 'user' ? t('你', 'You') : t('知行助手', 'Zhixing assistant')}
                </p>
                <div
                  className={`whitespace-pre-wrap break-words rounded-lg px-4 py-3 text-sm leading-7 ${
                    message.role === 'user' ? 'bg-primary text-primary-foreground' : 'bg-secondary/70 text-foreground'
                  }`}>
                  {message.content}
                </div>
                {message.sources.length > 0 && (
                  <div className="mt-2 flex flex-wrap gap-2">
                    {message.sources.map((source, index) => {
                      const href = citationHref(source);
                      const label = `[${index + 1}] ${source.title}`;
                      const className = 'rounded-full border border-border px-2.5 py-1 text-xs text-muted-foreground';
                      return href ? (
                        <a
                          key={`${message.id}-${source.targetType}-${source.targetId || source.title}`}
                          href={href}
                          {...(href.startsWith('/') ? {} : { target: '_blank', rel: 'noreferrer' })}
                          className={`${className} hover:border-primary/50 hover:text-foreground`}>
                          {label}
                        </a>
                      ) : (
                        <span
                          key={`${message.id}-${source.targetType}-${source.targetId || source.title}`}
                          className={className}>
                          {label}
                        </span>
                      );
                    })}
                  </div>
                )}
              </article>
            ))}
            {sending && (
              <p className="flex items-center gap-3 text-sm text-muted-foreground">
                {t('正在整理校园资料…', 'Looking through campus information…')}
                <button type="button" onClick={stop} className="text-xs text-primary hover:underline">
                  {t('停止生成', 'Stop')}
                </button>
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
          maxLength={12000}
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
