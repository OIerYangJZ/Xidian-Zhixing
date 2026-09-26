'use client';

import { useEffect, useState } from 'react';
import { useLanguage } from '@/hooks/useLanguage';

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
  const { t } = useLanguage();
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
        if (!response.ok)
          throw new Error(payload.message || t('校园日程暂时不可用。', 'Campus schedules are unavailable.'));
        return payload.data;
      })
      .then((data) => {
        if (!active) return;
        setItems(data.items || []);
        setCalendar(data.days || []);
        setSourceStatus(data.sourceStatus || 'connected');
      })
      .catch((requestError: unknown) => {
        if (active)
          setError(
            requestError instanceof Error
              ? requestError.message
              : t('校园日程暂时不可用。', 'Campus schedules are unavailable.'),
          );
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [date, days, mode, source, t]);

  return (
    <section className="mt-6 rounded-lg border border-border bg-card p-5">
      <div className="flex flex-wrap items-end gap-3">
        <label className="grid gap-1 text-sm">
          {t('开始日期', 'Start date')}
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
              {t('天数', 'Number of days')}
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
              {t('日程类型', 'Schedule type')}
              <select
                value={source}
                onChange={(event) => setSource(event.target.value)}
                className="rounded-lg border border-border bg-background px-3 py-2">
                <option value="all">{t('全部', 'All')}</option>
                <option value="course">{t('课程', 'Courses')}</option>
                <option value="exam">{t('考试', 'Exams')}</option>
                <option value="experiment">{t('实验', 'Labs')}</option>
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
        <p className="mt-5 text-sm text-muted-foreground">{t('正在读取日程…', 'Loading schedule…')}</p>
      ) : sourceStatus === 'not_connected' ? (
        <p className="mt-5 rounded-md bg-secondary p-4 text-sm leading-6 text-muted-foreground">
          {t(
            '学校尚未提供课表、考试和实验日程的正式数据接口，当前没有可展示的实时日程。',
            'The university has not provided official course, exam, or lab schedule data yet.',
          )}
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
            <p className="mt-5 text-sm text-muted-foreground">{t('当天没有日程。', 'No events today.')}</p>
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
                  <p className="mt-2 text-sm text-muted-foreground">{t('暂无日程', 'No events scheduled')}</p>
                )}
              </div>
            ))}
          </div>
        )
      ) : null}
    </section>
  );
}
