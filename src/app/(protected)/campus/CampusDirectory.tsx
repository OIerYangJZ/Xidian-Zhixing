'use client';

import Link from 'next/link';
import { PageHeader } from '@/components/ui/PageHeader';
import { useLanguage } from '@/hooks/useLanguage';
import { CampusService } from '@/lib/campus/catalog';

type CampusGroup = { title: string; services: CampusService[] };

export function CampusDirectory({
  quickLinks,
  groups,
}: {
  quickLinks: readonly { id: string; name: string; url: string; description: string }[];
  groups: CampusGroup[];
}) {
  const { t } = useLanguage();
  const serviceName = (name: string) =>
    t(name, name === '校园网用量' ? 'Campus network usage' : name === '在线设备' ? 'Online devices' : name);

  return (
    <main>
      <PageHeader title={t('校园服务', 'Campus')} />
      <section className="border-b border-border/80 px-4 py-4 sm:px-5">
        <h2 className="text-sm font-semibold">{t('学校官方入口', 'Official university links')}</h2>
        <div className="mt-3 flex flex-wrap gap-2">
          {quickLinks.map((link) => (
            <a
              key={link.id}
              href={link.url}
              target="_blank"
              rel="noreferrer"
              aria-label={`${t(
                link.name,
                link.id === 'ehall'
                  ? 'One-stop Service Hall'
                  : link.id === 'schoolnet'
                  ? 'Campus network self-service'
                  : 'Unified Identity System',
              )} — ${t(
                link.description,
                link.id === 'ehall'
                  ? 'Open the university service hall.'
                  : link.id === 'schoolnet'
                  ? 'Open the campus network portal.'
                  : 'Open the university identity portal.',
              )}`}
              className="rounded-full border border-border px-3 py-2 text-xs font-medium transition hover:bg-secondary">
              {t(
                link.name,
                link.id === 'ehall'
                  ? 'One-stop Service Hall'
                  : link.id === 'schoolnet'
                  ? 'Campus network self-service'
                  : 'Unified Identity System',
              )}
              <span className="ml-1.5 text-muted-foreground" aria-hidden="true">
                ↗
              </span>
            </a>
          ))}
        </div>
      </section>

      <div>
        {groups.map((group) => (
          <section key={group.title} className="border-b border-border/80">
            <div className="px-4 pb-2 pt-5 sm:px-5">
              <h2 className="text-base font-bold">
                {t(group.title, group.title === '校园生活' ? 'Campus life' : group.title)}
              </h2>
            </div>
            {group.services.map((service) => (
              <Link
                key={service.slug}
                href={service.path}
                className="group flex items-center gap-3 px-4 py-3.5 transition-colors hover:bg-secondary/50 sm:px-5">
                <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-secondary text-xs font-bold uppercase text-secondary-foreground">
                  {service.iconKey.slice(0, 2)}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-2">
                    <strong className="truncate text-sm font-semibold">{serviceName(service.name)}</strong>
                    <span
                      className={`shrink-0 rounded-full px-2 py-0.5 text-[10px] ${
                        service.enabled
                          ? 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300'
                          : 'bg-secondary text-muted-foreground'
                      }`}>
                      {service.authReady
                        ? t('已关联校园身份', 'Campus identity linked')
                        : t('需先完成校园认证', 'Campus verification required')}
                    </span>
                  </span>
                </span>
                <span
                  className="text-muted-foreground transition group-hover:translate-x-0.5 group-hover:text-foreground"
                  aria-hidden="true">
                  ›
                </span>
              </Link>
            ))}
          </section>
        ))}
      </div>
    </main>
  );
}
