'use client';

import {
  BuildingBusinessOffice,
  Feather,
  GridFeedCards,
  NotificationBell,
  Profile,
  Search,
  Mail,
  Settings,
} from '@/svg_components';
import { useSessionUserData } from '@/hooks/useSessionUserData';
import { useSession } from 'next-auth/react';
import { useNotificationsCountQuery } from '@/hooks/queries/useNotificationsCountQuery';
import { useCreatePostModal } from '@/hooks/useCreatePostModal';
import { useLanguage } from '@/hooks/useLanguage';
import { usePathname } from 'next/navigation';
import { LogoText } from './LogoText';
import { MenuBarItem } from './MenuBarItem';
import { ProfilePhotoOwn } from './ui/ProfilePhotoOwn';

function DesktopComposeButton() {
  const { launchCreatePost } = useCreatePostModal();
  const { t } = useLanguage();
  return (
    <button
      type="button"
      onClick={() => launchCreatePost({})}
      className="mt-4 hidden h-12 w-12 place-items-center self-center rounded-full bg-primary text-primary-foreground transition hover:brightness-95 md:grid xl:h-12 xl:w-full xl:self-auto xl:px-5 xl:text-base xl:font-bold">
      <span className="text-2xl leading-none xl:hidden" aria-hidden="true">
        ＋
      </span>
      <span className="hidden xl:inline">{t('发布', 'Post')}</span>
      <span className="sr-only xl:hidden">{t('发布动态', 'Create post')}</span>
    </button>
  );
}

function MobileComposeButton() {
  const { launchCreatePost } = useCreatePostModal();
  const { t } = useLanguage();
  const pathname = usePathname();
  if (pathname === '/ai' || pathname === '/messages') return null;
  return (
    <button
      type="button"
      onClick={() => launchCreatePost({})}
      aria-label={t('发布动态', 'Create post')}
      className="fixed bottom-[calc(84px+env(safe-area-inset-bottom))] right-4 z-30 grid h-14 w-14 place-items-center rounded-full bg-primary text-3xl font-light text-primary-foreground transition active:scale-95 md:hidden">
      +
    </button>
  );
}

export function MenuBar() {
  const { t } = useLanguage();
  const [user] = useSessionUserData();
  const { data: session } = useSession();
  const username = user?.username || 'user-not-found';
  const { data: notificationCount } = useNotificationsCountQuery();
  const items = [
    { children: t('首页', 'Home'), Icon: GridFeedCards, route: '/feed' },
    { children: t('探索', 'Explore'), Icon: Search, route: '/discover' },
    { children: t('校园', 'Campus'), Icon: BuildingBusinessOffice, route: '/campus' },
    { children: t('消息', 'Messages'), Icon: Mail, route: '/messages' },
    { children: t('知行 AI', 'Zhixing AI'), Icon: Feather, route: '/ai' },
    { children: t('通知', 'Notifications'), Icon: NotificationBell, route: '/notifications', badge: notificationCount },
    { children: t('我的', 'Profile'), Icon: Profile, route: `/${username}` },
    { children: t('设置', 'Settings'), Icon: Settings, route: '/settings' },
    ...(session?.user?.role === 'ADMIN'
      ? [{ children: t('内容审核', 'Moderation'), Icon: GridFeedCards, route: '/admin/moderation' }]
      : []),
  ];
  const mobileRoutes = ['/feed', '/campus', '/ai', '/messages', `/${username}`];
  const mobileItems = mobileRoutes
    .map((route) => items.find((item) => item.route === route))
    .filter((item): item is (typeof items)[number] => item !== undefined);

  return (
    <>
      <aside className="sticky top-0 hidden h-dvh w-[72px] flex-col items-center px-2 py-3 md:flex xl:w-[220px] xl:items-stretch xl:px-3">
        <a
          href="/"
          aria-label={t('西电知行首页', 'Zhixing home')}
          className="mb-5 flex h-12 items-center justify-center gap-3 rounded-full px-2 transition hover:bg-secondary/70 xl:justify-start xl:px-3">
          <img src="/campus-login/zhixing-logo.jpg" alt="" className="h-9 w-9 rounded-md object-cover" />
          <LogoText className="hidden text-xl text-foreground xl:block" />
        </a>
        <nav className="flex w-full flex-col gap-1" aria-label={t('主导航', 'Main navigation')}>
          {items.map((item) => (
            <MenuBarItem key={item.route} {...item} />
          ))}
        </nav>
        <DesktopComposeButton />
        <div className="mt-auto w-full border-t border-border/80 pt-3">
          <div className="mb-1 hidden items-center gap-3 rounded-lg px-2 py-2 xl:flex">
            <div className="h-9 w-9 shrink-0">
              <ProfilePhotoOwn />
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold">{user?.name || t('知行同学', 'Zhixing student')}</p>
              <p className="truncate text-xs text-muted-foreground">@{username}</p>
            </div>
          </div>
        </div>
      </aside>
      <nav
        className="fixed inset-x-0 bottom-0 z-40 flex h-[calc(64px+env(safe-area-inset-bottom))] items-center border-t border-border bg-background/95 px-2 pb-[env(safe-area-inset-bottom)] backdrop-blur-md md:hidden"
        aria-label="移动端主导航">
        {mobileItems.map((item) => (
          <MenuBarItem key={item.route} {...item} mobileTab />
        ))}
      </nav>
      <MobileComposeButton />
    </>
  );
}
