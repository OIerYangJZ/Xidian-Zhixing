'use client';

import { FormEvent, useCallback, useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { cn } from '@/lib/cn';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';
import { ApiError } from '@/lib/backend/client';
import { Avatar } from '@/components/ui/Avatar';
import {
  deleteConversation,
  listConversations,
  listMessages,
  openDirectConversation,
  recallMessage,
  searchUsers,
  sendMessage as sendDirectMessage,
} from '@/lib/backend/endpoints';
import type { ApiConversation, ApiDirectMessage } from '@/lib/backend/types';
import type { GetUser } from '@/types/definitions';

function ChatAvatar({ name, url, className }: { name: string; url: string; className?: string }) {
  return (
    <span className={cn('block shrink-0', className)}>
      <Avatar name={name || '知'} photoUrl={url} />
    </span>
  );
}

export function MessagesInbox() {
  const { t } = useLanguage();
  const requestedId = useSearchParams().get('c') || '';
  const [conversations, setConversations] = useState<ApiConversation[]>([]);
  const [activeId, setActiveId] = useState('');
  const [messages, setMessages] = useState<ApiDirectMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [search, setSearch] = useState('');
  const [searchResults, setSearchResults] = useState<GetUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const activeIdRef = useRef('');
  activeIdRef.current = activeId;
  const active = conversations.find((item) => item.id === activeId) || null;
  const locked = !!active && (active.awaitingReply || active.blockedByMe || active.blockedByPeer);

  const loadConversations = useCallback(async () => {
    const items = await listConversations();
    setConversations(items);
    return items;
  }, []);

  const openConversation = useCallback(
    async (id: string) => {
      setError('');
      try {
        // Reading also marks the conversation read on the server.
        const items = await listMessages(id);
        setActiveId(id);
        setMessages(items);
        setConversations((list) =>
          list.map((item) => (item.id === id ? { ...item, unreadCount: 0, hasUnread: false } : item)),
        );
      } catch (cause) {
        setError(
          cause instanceof ApiError ? cause.message : t('无法打开这段对话。', 'Could not open this conversation.'),
        );
      }
    },
    [t],
  );

  const archiveConversation = async () => {
    if (!activeId) return;
    try {
      // Hidden for this side only; a new message brings it back.
      await deleteConversation(activeId);
      setConversations((items) => items.filter((item) => item.id !== activeId));
      setActiveId('');
      setMessages([]);
    } catch {
      setError(t('对话归档失败。', 'Could not archive conversation.'));
    }
  };

  useEffect(() => {
    const keyword = search.trim();
    if (!keyword) {
      setSearchResults([]);
      return undefined;
    }
    const timer = window.setTimeout(() => {
      searchUsers(keyword)
        .then((users) => setSearchResults(users.filter((user) => !user.isOwnProfile).slice(0, 6)))
        .catch(() => setSearchResults([]));
    }, 250);
    return () => window.clearTimeout(timer);
  }, [search]);

  const startConversation = useCallback(
    async (user: GetUser) => {
      setError('');
      try {
        const conversation = await openDirectConversation(user.id);
        setSearch('');
        setSearchResults([]);
        await loadConversations();
        await openConversation(conversation.id);
      } catch (cause) {
        setError(
          cause instanceof ApiError ? cause.message : t('暂时无法开始对话。', 'Could not start this conversation.'),
        );
      }
    },
    [loadConversations, openConversation, t],
  );

  const sendMessage = useCallback(
    async (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault();
      const content = draft.trim();
      if (!activeId || !content || sending || locked) return;
      setSending(true);
      setError('');
      try {
        const message = await sendDirectMessage(activeId, content);
        setMessages((items) => [...items, message]);
        setDraft('');
        await loadConversations();
      } catch (cause) {
        if (cause instanceof ApiError && (cause.data as { awaitingReply?: boolean } | undefined)?.awaitingReply) {
          setConversations((items) =>
            items.map((item) => (item.id === activeId ? { ...item, awaitingReply: true } : item)),
          );
        }
        setError(
          cause instanceof ApiError
            ? cause.message
            : t('消息没有发送成功，请稍后再试。', 'Message not sent. Please try again.'),
        );
      } finally {
        setSending(false);
      }
    },
    [activeId, draft, loadConversations, locked, sending, t],
  );

  const recall = useCallback(
    async (message: ApiDirectMessage) => {
      if (!activeId) return;
      try {
        await recallMessage(activeId, message.id);
        await Promise.all([openConversation(activeId), loadConversations()]);
      } catch (cause) {
        setError(cause instanceof ApiError ? cause.message : t('撤回失败。', 'Could not recall.'));
      }
    },
    [activeId, loadConversations, openConversation, t],
  );

  useEffect(() => {
    let cancelled = false;
    loadConversations()
      .then((items) => {
        if (cancelled) return;
        const first = items.find((item) => item.id === requestedId) || (requestedId ? undefined : items[0]);
        if (first) openConversation(first.id);
      })
      .catch(() => setError(t('消息列表暂时无法加载。', 'Could not load messages.')))
      .finally(() => setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [loadConversations, openConversation, requestedId, t]);

  useEffect(() => {
    const timer = window.setInterval(async () => {
      try {
        await loadConversations();
        const id = activeIdRef.current;
        if (id) setMessages(await listMessages(id));
      } catch {
        // Polling is best-effort; the next tick retries.
      }
    }, 10000);
    return () => window.clearInterval(timer);
  }, [loadConversations]);

  const lockHint = !active
    ? ''
    : active.blockedByMe
    ? t('你已屏蔽对方，解除屏蔽后才能发送消息。', 'You blocked this person. Unblock to send messages.')
    : active.blockedByPeer
    ? t('对方已将你屏蔽，无法发送消息。', 'You cannot message this person.')
    : active.awaitingReply
    ? t('对方回复前只能发送一条消息。', 'You can send one message until they reply.')
    : '';

  return (
    <main className="flex h-[calc(100dvh-7.5rem-env(safe-area-inset-bottom))] min-h-0 flex-col md:h-dvh">
      <PageHeader title={t('消息', 'Messages')} />

      <div className="grid min-h-0 flex-1 grid-cols-1 overflow-hidden border-y border-border/80 bg-card md:my-4 md:min-h-[65dvh] md:grid-cols-[minmax(220px,260px)_minmax(0,1fr)] md:rounded-md md:border">
        <aside
          className={cn(
            'border-b border-border p-3 md:border-b-0 md:border-r',
            activeId ? 'hidden md:block' : 'block',
          )}>
          <div className="relative mb-3">
            <label className="sr-only" htmlFor="message-search">
              {t('搜索同学开始对话', 'Search for someone to message')}
            </label>
            <input
              id="message-search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder={t('搜索昵称，开始新对话', 'Search a name to start a chat')}
              className="w-full rounded-full bg-secondary/80 px-4 py-2.5 text-sm outline-none transition placeholder:text-muted-foreground focus:ring-2 focus:ring-primary/30"
            />
            {searchResults.length > 0 && (
              <div className="absolute inset-x-0 top-full z-10 mt-1 overflow-hidden rounded-lg border border-border bg-popover shadow-lg">
                {searchResults.map((user) => (
                  <button
                    key={user.id}
                    type="button"
                    onClick={() => startConversation(user)}
                    className="flex w-full items-center gap-3 px-3 py-2 text-left text-sm hover:bg-secondary/70">
                    <ChatAvatar name={user.name} url={user.profilePhoto || ''} className="h-8 w-8" />
                    <span className="min-w-0 flex-1 truncate">{user.name}</span>
                    {!user.canDirectMessage && (
                      <span className="text-xs text-muted-foreground">{t('未开放私信', 'Closed')}</span>
                    )}
                  </button>
                ))}
              </div>
            )}
          </div>
          <div className="flex gap-2 overflow-x-auto md:flex-col">
            {conversations.map((conversation) => (
              <button
                key={conversation.id}
                type="button"
                onClick={() => openConversation(conversation.id)}
                className={`flex min-w-40 flex-1 items-center gap-3 rounded-lg p-3 text-left transition md:min-w-0 ${
                  activeId === conversation.id ? 'bg-primary/10' : 'hover:bg-secondary/70'
                }`}>
                <ChatAvatar name={conversation.name} url={conversation.avatarUrl} className="h-10 w-10" />
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-2 text-sm font-semibold">
                    <span className="truncate">{conversation.name}</span>
                    {conversation.unreadCount > 0 && (
                      <span className="rounded-full bg-primary px-1.5 text-[11px] leading-4 text-primary-foreground">
                        {conversation.unreadCount}
                      </span>
                    )}
                    <span className="ml-auto shrink-0 text-[11px] font-normal text-muted-foreground">
                      {conversation.timeText}
                    </span>
                  </span>
                  <span className="mt-1 block truncate text-xs text-muted-foreground">{conversation.lastMessage}</span>
                </span>
              </button>
            ))}
            {!loading && conversations.length === 0 && (
              <p className="px-2 py-3 text-xs text-muted-foreground">
                {t('还没有消息。搜索昵称，开始认识一位同学。', 'No messages yet. Search a name to meet someone.')}
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
            {active && <ChatAvatar name={active.name} url={active.avatarUrl} className="h-9 w-9" />}
            <div className="min-w-0">
              <h2 className="truncate text-sm font-semibold">
                {active?.name || t('选择一段对话', 'Select a conversation')}
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
                  className={cn(
                    'flex max-w-[82%] flex-col gap-1',
                    message.fromMe ? 'items-end self-end' : 'self-start',
                  )}>
                  {message.recalled ? (
                    <p className="text-xs text-muted-foreground">
                      {message.fromMe
                        ? t('你撤回了一条消息', 'You recalled a message')
                        : t('对方撤回了一条消息', 'They recalled a message')}
                    </p>
                  ) : (
                    <div
                      className={cn(
                        'break-words rounded-lg px-3.5 py-2.5 text-sm leading-6',
                        message.fromMe ? 'bg-primary text-primary-foreground' : 'bg-secondary/80',
                      )}>
                      {message.replyToContent && (
                        <p className="border-current/40 mb-1 border-l-2 pl-2 text-xs opacity-75">
                          {message.replyToSender}: {message.replyToContent}
                        </p>
                      )}
                      {message.content}
                    </div>
                  )}
                  <span className="flex items-center gap-2 text-[11px] text-muted-foreground">
                    {message.timeText}
                    {message.fromMe && !message.recalled && message.isRead && <span>{t('已读', 'Read')}</span>}
                    {message.canRecall && (
                      <button type="button" onClick={() => recall(message)} className="hover:text-foreground">
                        {t('撤回', 'Recall')}
                      </button>
                    )}
                  </span>
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
          {lockHint && <p className="border-t border-border px-4 py-2 text-xs text-muted-foreground">{lockHint}</p>}
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
              maxLength={1000}
              disabled={!activeId || locked}
              placeholder={t('写一条消息…', 'Write a message…')}
              className="min-h-11 flex-1 resize-y rounded-lg bg-secondary/80 px-4 py-3 text-sm outline-none transition placeholder:text-muted-foreground focus:ring-2 focus:ring-primary/30 disabled:opacity-50"
            />
            <button
              type="submit"
              disabled={!activeId || sending || locked || !draft.trim()}
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
