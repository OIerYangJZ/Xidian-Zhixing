'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import { cn } from '@/lib/cn';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';

type Peer = { id: string; username: string | null; name: string | null; profilePhoto: string | null };
type Message = { id: string; conversationId: string; senderId: string; content: string; createdAt: string };
type ConversationSummary = {
  id: string;
  updatedAt: string;
  participant: Peer;
  lastMessage: Message | null;
  unread: boolean;
};
type ConversationDetail = { id: string; participants: Peer[]; messages: Message[] };

export function MessagesInbox() {
  const { t } = useLanguage();
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [activeId, setActiveId] = useState('');
  const [peer, setPeer] = useState<Peer | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [draft, setDraft] = useState('');
  const [username, setUsername] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const archiveConversation = async () => {
    if (!activeId) return;
    const response = await fetch(`/api/messages/${activeId}`, { method: 'PATCH' });
    if (!response.ok) {
      setError(t('对话归档失败。', 'Could not archive conversation.'));
      return;
    }
    setConversations((items) => items.filter((item) => item.id !== activeId));
    setActiveId('');
    setPeer(null);
    setMessages([]);
  };

  const openConversation = useCallback(
    async (id: string, summaryPeer?: Peer) => {
      setError('');
      try {
        const response = await fetch(`/api/messages/${id}`);
        if (!response.ok) {
          setError(t('无法打开这段对话。', 'Could not open this conversation.'));
          return;
        }
        const detail = (await response.json()) as ConversationDetail;
        setActiveId(id);
        setMessages(detail.messages);
        setPeer(summaryPeer || detail.participants[0] || null);
      } catch {
        setError(t('无法打开这段对话。', 'Could not open this conversation.'));
      }
    },
    [t],
  );

  const loadConversations = useCallback(
    async (selectId?: string) => {
      const response = await fetch('/api/messages');
      if (!response.ok) return;
      const items = (await response.json()) as ConversationSummary[];
      setConversations(items);
      const next = items.find((item) => item.id === (selectId || activeId)) || items[0];
      if (next) await openConversation(next.id, next.participant);
    },
    [activeId, openConversation],
  );

  const startConversation = useCallback(
    async (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault();
      const cleanUsername = username.trim();
      if (!cleanUsername) return;
      setError('');
      const response = await fetch('/api/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: cleanUsername }),
      });
      const result = (await response.json().catch(() => ({}))) as { id?: string; error?: string };
      if (!response.ok || !result.id) {
        setError(
          result.error === 'user_not_found'
            ? t('没有找到这位同学。', 'Student not found.')
            : result.error === 'direct_messages_not_allowed'
            ? t('对方暂不接受陌生人私信。', 'This person is not accepting messages from people they do not follow.')
            : t('暂时无法开始对话。', 'Could not start this conversation.'),
        );
        return;
      }
      setUsername('');
      await loadConversations(result.id);
    },
    [loadConversations, username, t],
  );

  const sendMessage = useCallback(
    async (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault();
      const content = draft.trim();
      if (!activeId || !content || sending) return;
      setSending(true);
      setError('');
      const response = await fetch(`/api/messages/${activeId}/messages`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content }),
      });
      setSending(false);
      if (!response.ok) {
        setError(t('消息没有发送成功，请稍后再试。', 'Message not sent. Please try again.'));
        return;
      }
      const message = (await response.json()) as Message;
      setMessages((items) => [...items, message]);
      setDraft('');
      await loadConversations(activeId);
    },
    [activeId, draft, loadConversations, sending, t],
  );

  useEffect(() => {
    let cancelled = false;
    fetch('/api/messages')
      .then(async (response) => {
        if (!response.ok) throw new Error(t('消息列表暂时无法加载。', 'Could not load messages.'));
        return (await response.json()) as ConversationSummary[];
      })
      .then((items) => {
        if (cancelled) return;
        setConversations(items);
        if (items[0]) openConversation(items[0].id, items[0].participant);
      })
      .catch((cause) =>
        setError(cause instanceof Error ? cause.message : t('消息列表暂时无法加载。', 'Could not load messages.')),
      )
      .finally(() => setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [openConversation, t]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      loadConversations().catch(() => setError(t('消息刷新失败。', 'Could not refresh messages.')));
    }, 10000);
    return () => window.clearInterval(timer);
  }, [loadConversations, t]);

  return (
    <main className="flex h-[calc(100dvh-7.5rem-env(safe-area-inset-bottom))] min-h-0 flex-col md:h-dvh">
      <PageHeader title={t('消息', 'Messages')} />

      <div className="grid min-h-0 flex-1 grid-cols-1 overflow-hidden border-y border-border/80 bg-card md:my-4 md:min-h-[65dvh] md:grid-cols-[minmax(220px,260px)_minmax(0,1fr)] md:rounded-md md:border">
        <aside
          className={cn(
            'border-b border-border p-3 md:border-b-0 md:border-r',
            activeId ? 'hidden md:block' : 'block',
          )}>
          <form onSubmit={startConversation} className="mb-3 flex gap-1.5">
            <label className="sr-only" htmlFor="message-username">
              {t('输入同学用户名', 'Enter a student username')}
            </label>
            <input
              id="message-username"
              value={username}
              onChange={(event) => setUsername(event.target.value)}
              placeholder={t('输入用户名', 'Enter username')}
              className="min-w-0 flex-1 rounded-full bg-secondary/80 px-4 py-2.5 text-sm outline-none transition placeholder:text-muted-foreground focus:ring-2 focus:ring-primary/30"
            />
            <button
              type="submit"
              aria-label={t('开始新对话', 'Start a conversation')}
              className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary text-xl font-light text-primary-foreground transition hover:brightness-95">
              ＋
            </button>
          </form>
          <div className="flex gap-2 overflow-x-auto md:flex-col">
            {conversations.map((conversation) => (
              <button
                key={conversation.id}
                type="button"
                onClick={() => openConversation(conversation.id, conversation.participant)}
                className={`flex min-w-40 flex-1 items-center gap-3 rounded-lg p-3 text-left transition md:min-w-0 ${
                  activeId === conversation.id ? 'bg-primary/10' : 'hover:bg-secondary/70'
                }`}>
                <span className="grid h-10 w-10 shrink-0 place-items-center overflow-hidden rounded-full bg-secondary text-sm font-semibold">
                  {conversation.participant.profilePhoto ? (
                    <img src={conversation.participant.profilePhoto} alt="" className="h-full w-full object-cover" />
                  ) : (
                    (conversation.participant.name || conversation.participant.username || t('知', 'Z')).slice(0, 1)
                  )}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-semibold">
                    {conversation.participant.name || conversation.participant.username}
                    {conversation.unread && (
                      <span
                        className="ml-2 inline-block h-2 w-2 rounded-full bg-primary"
                        aria-label={t('未读', 'Unread')}
                      />
                    )}
                  </span>
                  <span className="mt-1 block truncate text-xs text-muted-foreground">
                    {conversation.lastMessage?.content || t('开始一段新对话', 'Start a new conversation')}
                  </span>
                </span>
              </button>
            ))}
            {!loading && conversations.length === 0 && (
              <p className="px-2 py-3 text-xs text-muted-foreground">
                {t('还没有消息。输入用户名，开始认识一位同学。', 'No messages yet. Enter a username to meet someone.')}
              </p>
            )}
          </div>
        </aside>

        <section className={cn('min-h-0 min-w-0 flex-col', activeId ? 'flex' : 'hidden md:flex')}>
          <div className="flex min-h-[62px] items-center gap-3 border-b border-border px-4 py-2.5">
            {activeId && (
              <button
                type="button"
                onClick={() => setActiveId('')}
                aria-label={t('返回对话列表', 'Back to conversations')}
                className="grid h-9 w-9 shrink-0 place-items-center rounded-full text-xl transition hover:bg-secondary md:hidden">
                ‹
              </button>
            )}
            {peer?.profilePhoto && <img src={peer.profilePhoto} alt="" className="h-9 w-9 rounded-full object-cover" />}
            <div className="min-w-0">
              <h2 className="truncate text-sm font-semibold">
                {peer?.name || peer?.username || t('选择一段对话', 'Select a conversation')}
              </h2>
            </div>
            {activeId && (
              <button
                type="button"
                onClick={archiveConversation}
                className="ml-auto text-xs text-muted-foreground hover:text-foreground">
                {t('归档', 'Archive')}
              </button>
            )}
          </div>
          <div className="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto p-4" aria-live="polite">
            {loading ? (
              <p className="m-auto text-sm text-muted-foreground">{t('正在加载消息…', 'Loading messages…')}</p>
            ) : messages.length ? (
              messages.map((message) => (
                <div
                  key={message.id}
                  className={`max-w-[82%] break-words rounded-lg px-3.5 py-2.5 text-sm leading-6 ${
                    message.senderId === peer?.id
                      ? 'self-start bg-secondary/80'
                      : 'self-end bg-primary text-primary-foreground'
                  }`}>
                  {message.content}
                </div>
              ))
            ) : (
              <p className="m-auto max-w-xs text-center text-sm leading-6 text-muted-foreground">
                {t(
                  '给对方发条消息，聊聊课程、社团或校园生活。',
                  'Send a message to talk about classes, clubs, or campus life.',
                )}
              </p>
            )}
          </div>
          <form onSubmit={sendMessage} className="flex items-end gap-2 border-t border-border p-3">
            <label className="sr-only" htmlFor="message-draft">
              {t('输入消息', 'Enter a message')}
            </label>
            <textarea
              id="message-draft"
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === 'Enter' && !event.shiftKey) {
                  event.preventDefault();
                  event.currentTarget.form?.requestSubmit();
                }
              }}
              rows={1}
              maxLength={4000}
              disabled={!activeId}
              placeholder={t('写一条消息…', 'Write a message…')}
              className="min-h-11 flex-1 resize-y rounded-lg bg-secondary/80 px-4 py-3 text-sm outline-none transition placeholder:text-muted-foreground focus:ring-2 focus:ring-primary/30 disabled:opacity-50"
            />
            <button
              type="submit"
              disabled={!activeId || sending || !draft.trim()}
              className="rounded-md bg-primary px-4 py-3 text-sm font-medium text-primary-foreground disabled:opacity-50">
              {t('发送', 'Send')}
            </button>
          </form>
        </section>
      </div>
      {error && (
        <p role="alert" className="mt-3 text-sm text-destructive-foreground">
          {error}
        </p>
      )}
    </main>
  );
}
