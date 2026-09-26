'use client';

import { useEffect, useState } from 'react';

type ScheduleItem = {
  title: string;
  date: string;
  startTime?: string | null;
  endTime?: string | null;
  location?: string | null;
  teacher?: string | null;
  section?: string | null;
  kind?: string | null;
  seatNo?: string | null;
  examType?: string | null;
};
type CalendarDay = { date: string; items: ScheduleItem[] };

function todayInShanghai() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

function scheduleItemKey(item: ScheduleItem) {
  return [item.date, item.startTime, item.endTime, item.title, item.location, item.section].join('-');
}

function ScheduleCard({ item }: { item: ScheduleItem }) {
  return (
    <article className="rounded-md border border-border p-4">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h3 className="font-medium">{item.title}</h3>
        <span className="text-sm text-muted-foreground">
          {[item.startTime, item.endTime].filter(Boolean).join(' – ')}
        </span>
      </div>
      <p className="mt-2 text-sm text-muted-foreground">
        {[item.location, item.teacher, item.section, item.seatNo].filter(Boolean).join(' · ') ||
          item.kind ||
          item.examType ||
          ''}
      </p>
    </article>
  );
}

export function CampusScheduleView({ mode }: { mode: 'today' | 'calendar' }) {
  const [date, setDate] = useState('');
  const [days, setDays] = useState(7);
  const [source, setSource] = useState('all');
  const [items, setItems] = useState<ScheduleItem[]>([]);
  const [calendar, setCalendar] = useState<CalendarDay[]>([]);
  const [sourceStatus, setSourceStatus] = useState('not_connected');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    setDate(todayInShanghai());
  }, []);
  useEffect(() => {
    if (!date) return undefined;
    let active = true;
    setLoading(true);
    setError('');
    const url =
      mode === 'today'
        ? '/api/campus/schedules/today'
        : `/api/campus/schedules/calendar?startDate=${encodeURIComponent(date)}&days=${days}&source=${source}`;
    fetch(url, { cache: 'no-store' })
      .then(async (response) => {
        const payload = await response.json();
        if (!response.ok) throw new Error(payload.message || '校园日程暂时不可用。');
        return payload.data;
      })
      .then((data) => {
        if (!active) return;
        setItems(data.items || []);
        setCalendar(data.days || []);
        setSourceStatus(data.sourceStatus || 'connected');
      })
      .catch((requestError: unknown) => {
        if (active) setError(requestError instanceof Error ? requestError.message : '校园日程暂时不可用。');
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [date, days, mode, source]);

  return (
    <section className="mt-6 rounded-lg border border-border bg-card p-5">
      <div className="flex flex-wrap items-end gap-3">
        <label className="grid gap-1 text-sm">
          开始日期
          <input
            type="date"
            value={date}
            onChange={(event) => setDate(event.target.value)}
            className="rounded-lg border border-border bg-background px-3 py-2"
          />
        </label>
        {mode === 'calendar' ? (
          <>
            <label className="grid gap-1 text-sm">
              天数
              <input
                type="number"
                min={1}
                max={31}
                value={days}
                onChange={(event) => setDays(Math.min(31, Math.max(1, Number(event.target.value) || 1)))}
                className="w-24 rounded-lg border border-border bg-background px-3 py-2"
              />
            </label>
            <label className="grid gap-1 text-sm">
              日程类型
              <select
                value={source}
                onChange={(event) => setSource(event.target.value)}
                className="rounded-lg border border-border bg-background px-3 py-2">
                <option value="all">全部</option>
                <option value="course">课程</option>
                <option value="exam">考试</option>
                <option value="experiment">实验</option>
              </select>
            </label>
          </>
        ) : null}
      </div>
      {error ? (
        <p className="mt-5 text-sm text-destructive" role="alert">
          {error}
        </p>
      ) : loading ? (
        <p className="mt-5 text-sm text-muted-foreground">正在读取日程…</p>
      ) : sourceStatus === 'not_connected' ? (
        <p className="mt-5 rounded-md bg-secondary p-4 text-sm leading-6 text-muted-foreground">
          学校尚未提供课表、考试和实验日程的正式数据接口，当前没有可展示的实时日程。
        </p>
      ) : null}
      {!loading && !error && sourceStatus !== 'not_connected' ? (
        mode === 'today' ? (
          items.length ? (
            <div className="mt-5 space-y-3">
              {items.map((item) => (
                <ScheduleCard key={scheduleItemKey(item)} item={item} />
              ))}
            </div>
          ) : (
            <p className="mt-5 text-sm text-muted-foreground">当天没有日程。</p>
          )
        ) : (
          <div className="mt-5 space-y-3">
            {calendar.map((day) => (
              <div key={day.date} className="rounded-md border border-border p-4">
                <h2 className="font-semibold">{day.date}</h2>
                {day.items.length ? (
                  <div className="mt-3 space-y-3">
                    {day.items.map((item) => (
                      <ScheduleCard key={scheduleItemKey(item)} item={item} />
                    ))}
                  </div>
                ) : (
                  <p className="mt-2 text-sm text-muted-foreground">暂无日程</p>
                )}
              </div>
            ))}
          </div>
        )
      ) : null}
    </section>
  );
}
