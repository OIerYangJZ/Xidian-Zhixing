'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useLanguage } from '@/hooks/useLanguage';
import { SuggestedFollows } from './SuggestedFollows';

function getContext(pathname: string, t: (chinese: string, english: string) => string) {
  if (pathname.startsWith('/campus')) {
    return {
      links: [
        { label: t('今日校园', 'Campus today'), href: '/campus/today' },
        { label: t('校园日历', 'Campus calendar'), href: '/campus/calendar' },
      ],
    };
  }
  if (pathname.startsWith('/discover')) {
    return {
      links: [
        { label: t('校园服务', 'Campus services'), href: '/campus' },
        { label: t('知行 AI', 'Zhixing AI'), href: '/ai' },
      ],
    };
  }
  if (pathname.startsWith('/messages')) {
    return {
      links: [
        { label: t('探索同学', 'Discover people'), href: '/discover' },
        { label: t('校园动态', 'Campus posts'), href: '/feed' },
      ],
    };
  }
  if (pathname.startsWith('/ai')) {
    return {
      links: [
        { label: t('校园服务', 'Campus services'), href: '/campus' },
        { label: t('官方入口', 'Official links'), href: '/campus' },
      ],
    };
  }
  if (pathname.startsWith('/notifications')) {
    return {
      links: [
        { label: t('回到首页', 'Home'), href: '/feed' },
        { label: t('发现同学', 'Discover people'), href: '/discover' },
      ],
    };
  }
  return {
    links: [
      { label: t('今日校园', 'Campus today'), href: '/campus/today' },
      { label: t('校园服务', 'Campus services'), href: '/campus' },
      { label: t('知行 AI', 'Zhixing AI'), href: '/ai' },
    ],
  };
}

export function RightRail() {
  const { t } = useLanguage();
  const pathname = usePathname();
  const context = getContext(pathname, t);
  const officialLinks = [
    { label: t('学校官网', 'University website'), href: 'https://www.xidian.edu.cn/' },
    { label: t('一网通办', 'One-stop services'), href: 'https://ywtb.xidian.edu.cn/' },
    { label: t('图书馆', 'Library'), href: 'https://lib.xidian.edu.cn/' },
  ];

  return (
    <aside className="sticky top-0 hidden h-dvh overflow-y-auto px-1 py-4 xl:block">
      <div className="space-y-4">
        <Link
          href="/discover"
          className="flex h-11 items-center gap-3 rounded-full bg-secondary/80 px-4 text-sm text-muted-foreground transition hover:bg-secondary hover:text-foreground">
          <span className="text-lg leading-none" aria-hidden="true">
            ⌕
          </span>
          <span>{t('搜索同学、帖子和话题', 'Search people, posts, and topics')}</span>
        </Link>

        <SuggestedFollows />

        <section className="quiet-surface overflow-hidden rounded-lg">
          <div>
            {context.links.map((link) => (
              <Link
                key={link.href + link.label}
                href={link.href}
                className="group flex items-center justify-between border-t border-border/70 px-4 py-3 transition hover:bg-secondary/50">
                <span>
                  <strong className="block text-sm font-medium">{link.label}</strong>
                </span>
                <span
                  className="text-muted-foreground transition group-hover:translate-x-0.5 group-hover:text-foreground"
                  aria-hidden="true">
                  ↗
                </span>
              </Link>
            ))}
          </div>
        </section>

        <section className="quiet-surface rounded-lg p-4">
          <h2 className="text-sm font-semibold">{t('学校官方入口', 'Xidian official links')}</h2>
          <div className="mt-3 flex flex-wrap gap-2">
            {officialLinks.map((link) => (
              <a
                key={link.href}
                href={link.href}
                target="_blank"
                rel="noreferrer"
                className="rounded-full bg-secondary px-3 py-1.5 text-xs text-secondary-foreground transition hover:bg-secondary-accent">
                {link.label}
              </a>
            ))}
          </div>
        </section>

        <footer className="px-3 py-1 text-xs leading-5 text-muted-foreground">
          {t('西电知行 · 让所学有回响', 'Xidian Zhixing · Let learning resonate')}
          <br />
          <Link href="/terms" className="hover:underline">
            {t('使用条款', 'Terms')}
          </Link>
          <span aria-hidden="true"> · </span>
          <Link href="/privacy-policy" className="hover:underline">
            {t('隐私说明', 'Privacy')}
          </Link>
        </footer>
      </div>
    </aside>
  );
}
