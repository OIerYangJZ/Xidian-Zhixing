'use client';

import { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import ReactMarkdown, { type Components } from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';

type AISource = { citation: number; title: string; source: string | null; documentId: string };
export type AgentTraceEvent = {
  type: 'tool_call' | 'tool_result';
  toolCallId: string;
  tool: string;
  arguments?: unknown;
  argumentsValid?: boolean | null;
  result?: unknown;
  outcome?: string;
  durationMs?: number;
};
type AIMessageData = {
  id: string;
  role: 'USER' | 'ASSISTANT' | 'SYSTEM';
  content: string;
  sources: AISource[];
  createdAt: string;
  trace?: AgentTraceEvent[];
  durationMs?: number;
  status?: string;
  streaming?: boolean;
};
export type AIConversationData = {
  id: string;
  title: string;
  updatedAt: string;
  messages: AIMessageData[];
};

const markdownComponents: Components = {
  h1: ({ node: _node, ...props }) => <h1 className="mb-3 mt-5 text-xl font-semibold first:mt-0" {...props} />,
  h2: ({ node: _node, ...props }) => <h2 className="mb-2 mt-5 text-lg font-semibold first:mt-0" {...props} />,
  h3: ({ node: _node, ...props }) => <h3 className="mb-2 mt-4 text-base font-semibold first:mt-0" {...props} />,
  p: ({ node: _node, ...props }) => <p className="mb-3 last:mb-0" {...props} />,
  ul: ({ node: _node, ...props }) => <ul className="mb-3 list-disc space-y-1 pl-5 last:mb-0" {...props} />,
  ol: ({ node: _node, ...props }) => <ol className="mb-3 list-decimal space-y-1 pl-5 last:mb-0" {...props} />,
  blockquote: ({ node: _node, ...props }) => (
    <blockquote className="my-3 border-l-2 border-primary/50 pl-3 text-muted-foreground" {...props} />
  ),
  a: ({ node: _node, ...props }) => (
    <a className="text-primary underline underline-offset-2" target="_blank" rel="noreferrer" {...props} />
  ),
  table: ({ node: _node, ...props }) => (
    <div className="my-3 max-w-full overflow-x-auto">
      <table className="min-w-full border-collapse text-left text-xs" {...props} />
    </div>
  ),
  th: ({ node: _node, ...props }) => (
    <th className="border border-border bg-background/70 px-2 py-1.5 font-semibold" {...props} />
  ),
  td: ({ node: _node, ...props }) => <td className="border border-border px-2 py-1.5 align-top" {...props} />,
  pre: ({ node: _node, ...props }) => (
    <pre className="my-3 overflow-x-auto rounded-md bg-background p-3 text-xs leading-5" {...props} />
  ),
  code: ({ node: _node, className, children, ...props }) => {
    const block = Boolean(className);
    return (
      <code
        className={block ? `${className} font-mono` : 'rounded bg-background/70 px-1 py-0.5 font-mono text-[0.9em]'}
        {...props}>
        {children}
      </code>
    );
  },
  hr: ({ node: _node, ...props }) => <hr className="my-4 border-border" {...props} />,
};

function prettyValue(value: unknown) {
  if (typeof value === 'string') {
    try {
      return JSON.stringify(JSON.parse(value), null, 2);
    } catch {
      return value;
    }
  }
  return JSON.stringify(value, null, 2) || String(value ?? '');
}

function toolLabel(tool: string, language: string) {
  const labels: Record<string, [string, string]> = {
    find_files: ['按标题查找资料', 'Find files by title'],
    search_docs: ['检索资料正文', 'Search document text'],
    read_file: ['读取原文文件', 'Read source file'],
    read_files: ['批量读取资料原文', 'Read source files'],
    get_current_datetime: ['读取当前北京时间', 'Read current Beijing time'],
    search_all_sources: ['并行检索本地与网页', 'Search local and web sources'],
    read_web_pages: ['批量读取网页原文', 'Read public web pages'],
    list_campus_api_capabilities: ['查看已授权校园接口', 'List campus API access'],
    call_campus_api: ['调用校园功能接口', 'Call campus API'],
  };
  return labels[tool]?.[language === 'zh' ? 0 : 1] || tool;
}

function formatDuration(durationMs: number, language: string) {
  const seconds = Math.max(1, Math.round(durationMs / 1000));
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  if (language === 'zh') {
    return minutes > 0 ? `${minutes} 分 ${remainingSeconds} 秒` : `${seconds} 秒`;
  }
  return minutes > 0
    ? `${minutes} min${minutes === 1 ? '' : 's'} ${remainingSeconds} sec${remainingSeconds === 1 ? '' : 's'}`
    : `${seconds} sec${seconds === 1 ? '' : 's'}`;
}

function AgentTrace({ message, language }: { message: AIMessageData; language: string }) {
  const calls = (message.trace || [])
    .filter((event) => event.type === 'tool_call')
    .map((call) => ({
      ...call,
      returned: message.trace?.find((event) => event.type === 'tool_result' && event.toolCallId === call.toolCallId),
    }));
  if (calls.length === 0 && message.durationMs === undefined) return null;

  const activityLabel = message.streaming
    ? language === 'zh'
      ? `正在执行 · ${calls.length} 次工具调用`
      : `Working · ${calls.length} tool calls`
    : language === 'zh'
      ? `${message.durationMs === undefined ? '执行完成' : `工作了 ${formatDuration(message.durationMs, language)}`} · ${calls.length} 次工具调用`
      : `${message.durationMs === undefined ? 'Complete' : `Worked for ${formatDuration(message.durationMs, language)}`} · ${calls.length} tool calls`;

  return (
    <details className="mb-2 overflow-hidden rounded-lg border border-border/80 bg-background/50 text-xs">
      <summary className="cursor-pointer select-none px-3 py-2.5 font-medium text-muted-foreground hover:text-foreground">
        {activityLabel}
      </summary>
      <div className="space-y-3 border-t border-border/80 p-3">
        {calls.map((call, index) => (
          <details key={call.toolCallId} className="rounded-md border border-border/70 bg-card">
            <summary className="flex cursor-pointer list-none items-center gap-2 px-3 py-2.5">
              <span className="text-primary">
                {call.returned?.outcome === 'failed' ? '!' : call.returned ? '✓' : '◌'}
              </span>
              <span className="font-medium">
                {index + 1}. {toolLabel(call.tool, language)}
              </span>
              {call.argumentsValid === false && (
                <span className="text-destructive-foreground">
                  {language === 'zh' ? '参数未通过校验' : 'Invalid arguments'}
                </span>
              )}
              <span className="ml-auto text-muted-foreground">
                {call.returned
                  ? `${language === 'zh' ? '已完成' : 'Done'}${
                      call.returned.durationMs === undefined ? '' : ` · ${call.returned.durationMs} ms`
                    }`
                  : language === 'zh'
                  ? '执行中'
                  : 'Running'}
              </span>
            </summary>
            <div className="space-y-3 border-t border-border/70 p-3">
              <div>
                <p className="mb-1 font-medium text-muted-foreground">
                  {language === 'zh' ? '模型发出的原始工具指令' : 'Raw tool call from model'}
                </p>
                <pre className="max-h-56 overflow-auto whitespace-pre-wrap break-all rounded bg-background p-2 font-mono text-[11px] leading-5">
                  {prettyValue(call.arguments)}
                </pre>
              </div>
              {call.returned && (
                <details>
                  <summary className="cursor-pointer font-medium text-muted-foreground">
                    {language === 'zh' ? '查看工具实际返回内容' : 'Inspect tool result'}
                  </summary>
                  <pre className="mt-2 max-h-[32rem] overflow-auto whitespace-pre-wrap break-words rounded bg-background p-2 font-mono text-[11px] leading-5">
                    {prettyValue(call.returned.result)}
                  </pre>
                </details>
              )}
            </div>
          </details>
        ))}
      </div>
    </details>
  );
}

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
  const requestAbortRef = useRef<AbortController | null>(null);
  useEffect(() => () => requestAbortRef.current?.abort(), []);
  const activeConversation = useMemo(
    () => conversations.find((conversation) => conversation.id === activeId),
    [activeId, conversations],
  );
  const lastMessage = activeConversation?.messages[activeConversation.messages.length - 1];

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ block: 'end' });
  }, [
    activeId,
    activeConversation?.messages.length,
    lastMessage?.content.length,
    lastMessage?.trace?.length,
    lastMessage?.status,
    sending,
  ]);

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
    setDraft('');
    const localConversationId = activeId || `pending-${Date.now()}`;
    const pendingUserId = `pending-user-${Date.now()}`;
    const pendingAssistantId = `pending-assistant-${Date.now()}`;
    const timestamp = new Date().toISOString();
    const userMessage: AIMessageData = {
      id: pendingUserId,
      role: 'USER',
      content,
      sources: [],
      createdAt: timestamp,
    };
    const assistantMessage: AIMessageData = {
      id: pendingAssistantId,
      role: 'ASSISTANT',
      content: '',
      sources: [],
      trace: [],
      status: t('正在分析问题…', 'Thinking…'),
      streaming: true,
      createdAt: timestamp,
    };
    setActiveId(localConversationId);
    setConversations((items) => {
      const exists = items.some((conversation) => conversation.id === localConversationId);
      if (!exists) {
        return [
          {
            id: localConversationId,
            title: content.slice(0, 32),
            updatedAt: timestamp,
            messages: [userMessage, assistantMessage],
          },
          ...items,
        ];
      }
      return items.map((conversation) =>
        conversation.id === localConversationId
          ? { ...conversation, messages: [...conversation.messages, userMessage, assistantMessage] }
          : conversation,
      );
    });

    const updateAssistant = (update: Partial<AIMessageData>) => {
      setConversations((items) =>
        items.map((conversation) =>
          conversation.messages.some((message) => message.id === pendingAssistantId)
            ? {
                ...conversation,
                messages: conversation.messages.map((message) =>
                  message.id === pendingAssistantId ? { ...message, ...update } : message,
                ),
              }
            : conversation,
        ),
      );
    };
    let persistedUserId = pendingUserId;
    const discardFailedTurn = () => {
      setConversations((items) =>
        items.map((conversation) => ({
          ...conversation,
          messages: conversation.messages.filter(
            (message) =>
              message.id !== persistedUserId && message.id !== pendingUserId && message.id !== pendingAssistantId,
          ),
        })),
      );
    };
    const requestAbort = new AbortController();
    requestAbortRef.current = requestAbort;
    let responseReader: ReadableStreamDefaultReader<Uint8Array> | undefined;

    try {
      const response = await fetch('/api/ai/chat/stream', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content, conversationId: activeId || undefined, language }),
        signal: requestAbort.signal,
      });

      if (!response.ok || !response.body) {
        const result = (await response.json().catch(() => ({}))) as {
          data?: { code?: string };
          message?: string;
        };
        setConversations((items) =>
          items.flatMap((conversation) => {
            const messages = conversation.messages.filter(
              (message) => message.id !== pendingUserId && message.id !== pendingAssistantId,
            );
            if (
              conversation.id === localConversationId &&
              conversation.id.startsWith('pending-') &&
              messages.length === 0
            ) {
              return [];
            }
            return [{ ...conversation, messages }];
          }),
        );
        setError(
          result.data?.code === 'corpus_not_configured'
            ? t('本地校园资料库尚未配置。', 'The local campus library is not configured.')
            : result.data?.code === 'ai_not_configured'
            ? t('DeepSeek API 尚未配置。', 'The DeepSeek API is not configured.')
            : result.data?.code === 'harness_unavailable'
            ? t('AI Agent 服务暂时无法连接。', 'The AI Agent service is unavailable.')
            : result.message || t('回答暂时没有生成，请稍后再试。', 'No answer was generated. Please try again.'),
        );
        setDraft(content);
        setSending(false);
        return;
      }

      const reader = response.body.getReader();
      responseReader = reader;
      const decoder = new TextDecoder();
      let pending = '';
      let terminalEventReceived = false;
      const handleEvent = (payload: Record<string, unknown>) => {
        if (payload.type === 'start') {
          const conversationId = String(payload.conversationId || localConversationId);
          const startedUser = payload.userMessage as AIMessageData | undefined;
          if (startedUser) persistedUserId = startedUser.id;
          setActiveId(conversationId);
          setConversations((items) =>
            items.map((conversation) =>
              conversation.id === localConversationId
                ? {
                    ...conversation,
                    id: conversationId,
                    title: conversation.title || content.slice(0, 32),
                    messages: conversation.messages.map((message) =>
                      message.id === pendingUserId && startedUser ? startedUser : message,
                    ),
                  }
                : conversation,
            ),
          );
        } else if (payload.type === 'status') {
          updateAssistant({
            status: typeof payload.message === 'string' ? payload.message : t('正在思考…', 'Thinking…'),
          });
        } else if (payload.type === 'tool_call' || payload.type === 'tool_result') {
          const traceEvent = payload as unknown as AgentTraceEvent;
          setConversations((items) =>
            items.map((conversation) =>
              conversation.messages.some((message) => message.id === pendingAssistantId)
                ? {
                    ...conversation,
                    messages: conversation.messages.map((message) =>
                      message.id === pendingAssistantId
                        ? { ...message, trace: [...(message.trace || []), traceEvent] }
                        : message,
                    ),
                  }
                : conversation,
            ),
          );
        } else if (payload.type === 'answer_reset') {
          updateAssistant({ content: '' });
        } else if (payload.type === 'answer_delta' && typeof payload.text === 'string') {
          setConversations((items) =>
            items.map((conversation) =>
              conversation.messages.some((message) => message.id === pendingAssistantId)
                ? {
                    ...conversation,
                    messages: conversation.messages.map((message) =>
                      message.id === pendingAssistantId
                        ? { ...message, content: message.content + payload.text }
                        : message,
                    ),
                  }
                : conversation,
            ),
          );
        } else if (payload.type === 'done') {
          terminalEventReceived = true;
          const message = payload.message as AIMessageData;
          setConversations((items) =>
            items.map((conversation) =>
              conversation.id === String(payload.conversationId || localConversationId)
                ? {
                    ...conversation,
                    title: conversation.title === '新对话' ? content.slice(0, 32) : conversation.title,
                    updatedAt: message.createdAt,
                    messages: conversation.messages.map((item) =>
                      item.id === pendingAssistantId
                        ? {
                            ...item,
                            ...message,
                            durationMs: typeof payload.durationMs === 'number' ? payload.durationMs : undefined,
                            status: t('已完成', 'Complete'),
                            streaming: false,
                          }
                        : item,
                    ),
                  }
                : conversation,
            ),
          );
          setSending(false);
        } else if (payload.type === 'error') {
          terminalEventReceived = true;
          const httpStatus = typeof payload.httpStatus === 'number' ? payload.httpStatus : undefined;
          setError(
            payload.code === 'ai_busy'
              ? t('AI 服务繁忙，请稍后重试。', 'The AI service is busy. Please retry shortly.')
              : payload.code === 'ai_timeout'
              ? t('本轮回答超时，请缩小问题范围后重试。', 'This turn timed out. Please narrow the question and retry.')
              : payload.code === 'ai_budget_exceeded'
              ? t(
                  '本轮检索已达到上限，请缩小问题范围后重试。',
                  'This turn reached its search budget. Please narrow the question and retry.',
                )
              : httpStatus === 402
              ? t(
                  'DeepSeek 返回 HTTP 402，请检查 API 账户额度和计费状态。',
                  'DeepSeek returned HTTP 402. Check API balance and billing status.',
                )
              : httpStatus
              ? t(`DeepSeek 返回 HTTP ${httpStatus}。`, `DeepSeek returned HTTP ${httpStatus}.`)
              : t(
                  'DeepSeek 暂时无法完成请求，请稍后重试。',
                  'DeepSeek could not complete the request. Please retry later.',
                ),
          );
          discardFailedTurn();
          setDraft(content);
          setSending(false);
        }
      };

      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        pending += decoder.decode(value, { stream: true });
        let boundary = pending.indexOf('\n\n');
        while (boundary >= 0) {
          const frame = pending.slice(0, boundary);
          pending = pending.slice(boundary + 2);
          const data = frame
            .split(/\r?\n/)
            .find((line) => line.startsWith('data:'))
            ?.slice(5)
            .trim();
          if (data) {
            try {
              handleEvent(JSON.parse(data) as Record<string, unknown>);
            } catch {
              // Ignore malformed stream frames and keep processing later events.
            }
          }
          boundary = pending.indexOf('\n\n');
        }
      }
      if (!terminalEventReceived) {
        setError(t('响应流意外中断，请重试。', 'The response stream ended unexpectedly. Please retry.'));
        discardFailedTurn();
        setDraft(content);
        setSending(false);
      }
    } catch {
      setError(t('AI Agent 服务暂时无法连接。', 'The AI Agent service is unavailable.'));
      discardFailedTurn();
      setDraft(content);
      setSending(false);
    } finally {
      await responseReader?.cancel().catch(() => undefined);
      responseReader?.releaseLock();
      if (requestAbortRef.current === requestAbort) requestAbortRef.current = null;
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
                className={message.role === 'USER' ? 'ml-auto max-w-[88%]' : 'mr-auto max-w-[92%]'}>
                {message.role === 'ASSISTANT' && <AgentTrace message={message} language={language} />}
                <p className="mb-1 text-xs text-muted-foreground">
                  {message.role === 'USER' ? t('你', 'You') : t('知行助手', 'Zhixing assistant')}
                </p>
                <div
                  className={`break-words rounded-lg px-4 py-3 text-sm leading-7 ${
                    message.role === 'USER'
                      ? 'whitespace-pre-wrap bg-primary text-primary-foreground'
                      : 'bg-secondary/70 text-foreground'
                  }`}>
                  {message.role === 'USER' ? (
                    message.content
                  ) : (
                    <div className="break-words">
                      <ReactMarkdown remarkPlugins={[remarkGfm]} components={markdownComponents}>
                        {message.content}
                      </ReactMarkdown>
                      {message.streaming && (
                        <div className="mt-3 flex items-center gap-2 text-xs text-muted-foreground" aria-live="polite">
                          <span className="inline-block animate-spin" aria-hidden="true">
                            ◌
                          </span>
                          <span>{message.status || t('正在思考…', 'Thinking…')}</span>
                        </div>
                      )}
                    </div>
                  )}
                </div>
                {message.sources.length > 0 && (
                  <div className="mt-2 flex flex-wrap gap-2">
                    {message.sources.map((source) => (
                      <a
                        key={`${message.id}-${source.citation}`}
                        href={source.source || undefined}
                        target={source.source ? '_blank' : undefined}
                        rel={source.source ? 'noreferrer' : undefined}
                        className="rounded-full border border-border px-2.5 py-1 text-xs text-muted-foreground">
                        [{source.citation}] {source.title}
                      </a>
                    ))}
                  </div>
                )}
              </article>
            ))}
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
