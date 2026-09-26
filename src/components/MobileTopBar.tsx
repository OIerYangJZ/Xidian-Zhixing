'use client';

import { usePathname } from 'next/navigation';
import Link from 'next/link';
import { useSessionUserData } from '@/hooks/useSessionUserData';
import { useNotificationsCountQuery } from '@/hooks/queries/useNotificationsCountQuery';
import { NotificationBell, Search, Settings } from '@/svg_components';
import { useLanguage } from '@/hooks/useLanguage';

export function MobileTopBar() {
  const { t } = useLanguage();
  const pathname = usePathname();
  const [user] = useSessionUserData();
  const { data: notificationCount } = useNotificationsCountQuery();
  const titles: Record<string, string> = {
    '/feed': t('首页', 'Home'),
    '/discover': t('探索', 'Explore'),
    '/campus': t('校园', 'Campus'),
    '/messages': t('消息', 'Messages'),
    '/ai': t('知行 AI', 'Zhixing AI'),
    '/notifications': t('通知', 'Notifications'),
  };
  const title = titles[pathname] || (pathname.startsWith('/campus/') ? t('校园', 'Campus') : 'Zhixing');
  return (
    <header className="sticky top-0 z-30 flex h-14 items-center justify-between border-b border-border/80 bg-background/85 px-4 backdrop-blur-xl md:hidden">
      <Link href="/" className="flex h-10 items-center gap-2 rounded-full pr-2" aria-label="西电知行首页">
        <img src="/campus-login/zhixing-logo.jpg" alt="" className="h-8 w-8 rounded-md object-cover" />
      </Link>
      <span className="absolute left-1/2 -translate-x-1/2 text-[15px] font-semibold">{title}</span>
      <div className="flex items-center gap-1">
        <Link
          href="/discover"
          aria-label={t('探索', 'Explore')}
          className="grid h-10 w-10 place-items-center rounded-full text-foreground transition hover:bg-secondary">
          <Search className="h-5 w-5 stroke-current" />
        </Link>
        <Link
          href="/settings"
          aria-label={t('设置', 'Settings')}
          className="grid h-10 w-10 place-items-center rounded-full text-foreground transition hover:bg-secondary">
          <Settings className="h-5 w-5 stroke-current" />
        </Link>
        <Link
          href="/notifications"
          aria-label={t('通知', 'Notifications')}
          className="relative grid h-10 w-10 place-items-center rounded-full text-foreground transition hover:bg-secondary">
          <NotificationBell className="h-5 w-5 stroke-current" />
          {!!notificationCount && (
            <span className="absolute right-1 top-1 grid min-h-4 min-w-4 place-items-center rounded-full bg-primary px-1 text-[9px] font-bold text-primary-foreground">
              {notificationCount > 99 ? '99+' : notificationCount}
            </span>
          )}
        </Link>
        <Link
          href={user?.username ? `/${user.username}` : '/feed'}
          aria-label="个人主页"
          className="grid h-9 w-9 place-items-center overflow-hidden rounded-full bg-secondary">
          {user?.profilePhoto ? (
            <img src={user.profilePhoto} alt="" className="h-full w-full object-cover" />
          ) : (
            <span className="text-xs font-semibold">{user?.name?.slice(0, 1) || '知'}</span>
          )}
        </Link>
      </div>
    </header>
  );
}
