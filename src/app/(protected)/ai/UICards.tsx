'use client';

/* eslint-disable react/no-array-index-key -- Card lists are immutable after a message is committed. */

import { useState } from 'react';
import { safeSourceURL, validateUI, type UICard, type UIService, type UISource } from '@/lib/ai/ui';

type CardProps = {
  sources: UISource[];
  language: string;
  disabled: boolean;
  onFollowUp: (prompt: string) => void;
};

const buttonClass =
  'rounded-md border border-border px-3 py-2 text-xs font-medium text-primary transition hover:bg-primary/5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary disabled:opacity-50';
const cardClass = 'min-w-0 rounded-lg border border-border bg-card p-4 text-sm';

function SourceReferences({ citations, sources }: { citations: number[]; sources: UISource[] }) {
  return (
    <div className="flex flex-wrap gap-2 text-xs text-muted-foreground">
      {[...new Set(citations)].map((citation) => {
        const source = sources.find((item) => item.citation === citation);
        if (!source) return null;
        const href = safeSourceURL(source.source);
        const label = `[${citation}] ${source.title}`;
        return href ? (
          <a
            key={citation}
            href={href}
            target="_blank"
            rel="noreferrer"
            className="break-words underline underline-offset-2">
            {label}
          </a>
        ) : (
          <span key={citation} className="break-words">
            {label}
          </span>
        );
      })}
    </div>
  );
}

function SourceList({
  card,
  sources,
  language,
  disabled,
  onFollowUp,
}: CardProps & { card: Extract<UICard, { type: 'source_list' }> }) {
  const [filter, setFilter] = useState('');
  const zh = language === 'zh';
  const items = sources.filter(
    (source) =>
      card.citations.includes(source.citation) &&
      source.title.toLocaleLowerCase().includes(filter.trim().toLocaleLowerCase()),
  );
  return (
    <section aria-label={zh ? '相关资料' : 'Sources'} className={cardClass}>
      <h3 className="mb-3 font-semibold">{zh ? '相关资料' : 'Sources'}</h3>
      <label className="mb-3 block">
        <span className="sr-only">{zh ? '按标题筛选资料' : 'Filter sources by title'}</span>
        <input
          type="search"
          value={filter}
          onChange={(event) => setFilter(event.target.value)}
          placeholder={zh ? '按标题筛选资料' : 'Filter sources by title'}
          className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
        />
      </label>
      <ul className="space-y-3">
        {items.map((source) => (
          <li key={source.citation} className="space-y-2 rounded-md bg-secondary/50 p-3">
            <SourceReferences
              citations={card.citations.filter((citation) => citation === source.citation)}
              sources={sources}
            />
            <button
              type="button"
              disabled={disabled}
              className={buttonClass}
              onClick={() =>
                onFollowUp(
                  zh
                    ? `请进一步解释资料「${source.title}」${
                        source.source ? `（${source.source}）` : ''
                      }与当前问题相关的内容，请重新核实原文。`
                    : `Please explain how “${source.title}”${
                        source.source ? ` (${source.source})` : ''
                      } relates to my question. Recheck the original source.`,
                )
              }>
              {zh ? '继续追问这份资料' : 'Ask about this source'}
            </button>
          </li>
        ))}
      </ul>
      {!items.length && (
        <p role="status" className="text-muted-foreground">
          {zh ? '没有匹配的资料。' : 'No matching sources.'}
        </p>
      )}
    </section>
  );
}

function Guide({
  card,
  sources,
  language,
  disabled,
  onFollowUp,
}: CardProps & { card: Extract<UICard, { type: 'guide' }> }) {
  const [checked, setChecked] = useState<number[]>([]);
  const zh = language === 'zh';
  return (
    <section aria-label={card.title} className={cardClass}>
      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
        <h3 className="font-semibold">{card.title}</h3>
        <span aria-live="polite" className="text-xs text-muted-foreground">
          {checked.length}/{card.steps.length}
        </span>
      </div>
      <p className="mb-3 text-xs text-muted-foreground">
        {zh
          ? '勾选仅记录本页进度，实际办理请以学校系统为准。'
          : 'Checks track progress on this page. Complete the actual process in the university system.'}
      </p>
      <ol className="space-y-3">
        {card.steps.map((step, index) => (
          <li key={index} className="rounded-md bg-secondary/50 p-3">
            <label className="flex cursor-pointer items-start gap-3">
              <input
                type="checkbox"
                checked={checked.includes(index)}
                onChange={(event) =>
                  setChecked((items) =>
                    event.target.checked ? [...items, index] : items.filter((item) => item !== index),
                  )
                }
                className="mt-1 h-4 w-4 shrink-0 accent-primary"
              />
              <span className={checked.includes(index) ? 'text-muted-foreground line-through' : 'font-medium'}>
                {index + 1}. {step.title}
              </span>
            </label>
            <details className="mt-2">
              <summary className="cursor-pointer text-xs text-primary">
                {zh ? '查看说明与依据' : 'Details and sources'}
              </summary>
              <p className="my-2 whitespace-pre-wrap break-words text-sm leading-6">{step.detail}</p>
              <SourceReferences citations={step.citations} sources={sources} />
            </details>
            <button
              type="button"
              disabled={disabled}
              className={`${buttonClass} mt-3`}
              onClick={() =>
                onFollowUp(
                  zh
                    ? `请详细解释「${card.title}」的第 ${index + 1} 步「${step.title}」：${
                        step.detail
                      }。请重新核实来源并说明具体操作。`
                    : `Explain step ${index + 1} of “${card.title}”, “${step.title}”: ${
                        step.detail
                      }. Recheck the sources and explain what to do.`,
                )
              }>
              {zh ? '追问这一步' : 'Ask about this step'}
            </button>
          </li>
        ))}
      </ol>
    </section>
  );
}

export function UICards({ value, services, ...props }: CardProps & { value: unknown; services: UIService[] }) {
  const { ui } = validateUI(value, props.sources);
  if (!ui) return null;
  const zh = props.language === 'zh';
  return (
    <div className="mt-3 grid min-w-0 gap-3">
      {ui.cards.map((card, index) => {
        if (card.type === 'source_list') return <SourceList key={index} card={card} {...props} />;
        if (card.type === 'guide') return <Guide key={index} card={card} {...props} />;
        return (
          <section key={index} aria-label={zh ? '校园服务入口' : 'Campus services'} className={cardClass}>
            <h3 className="mb-3 font-semibold">{zh ? '校园服务入口' : 'Campus services'}</h3>
            <ul className="space-y-3">
              {[...new Set(card.serviceIds)].map((id) => {
                const service = services.find((item) => item.id === id);
                if (!service) return null;
                const external = !service.href.startsWith('/');
                return (
                  <li key={id} className="space-y-2 rounded-md bg-secondary/50 p-3">
                    <p className="font-medium">{service.name}</p>
                    <p className="break-words text-xs leading-5 text-muted-foreground">{service.description}</p>
                    {service.status === 'available' ? (
                      <a
                        href={service.href}
                        target={external ? '_blank' : undefined}
                        rel={external ? 'noreferrer' : undefined}
                        className={`${buttonClass} inline-block`}>
                        {zh
                          ? external
                            ? '打开官方入口'
                            : '进入服务页'
                          : external
                          ? 'Open official site'
                          : 'Open service'}
                      </a>
                    ) : (
                      <p className="text-xs text-muted-foreground">{zh ? '待接入' : 'Not connected'}</p>
                    )}
                  </li>
                );
              })}
            </ul>
          </section>
        );
      })}
    </div>
  );
}
