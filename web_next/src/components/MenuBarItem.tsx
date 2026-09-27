'use client';

import { useActiveRouteChecker } from '@/hooks/useActiveRouteChecker';
import { useDialogs } from '@/hooks/useDialogs';
import { cn } from '@/lib/cn';
import { useAuthActions } from '@/lib/backend/session';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import React, { SVGProps, useCallback } from 'react';
import { useLanguage } from '@/hooks/useLanguage';
import { Badge } from './ui/Badge';
import { ButtonNaked } from './ui/ButtonNaked';

export function MenuBarItem({
  children,
  Icon,
  route,
  badge,
  mobileTab = false,
}: {
  children: React.ReactNode;
  Icon: (props: SVGProps<SVGSVGElement>) => JSX.Element;
  route: string;
  badge?: number;
  mobileTab?: boolean;
}) {
  const router = useRouter();
  const [isActive] = useActiveRouteChecker(route);
  const { confirm } = useDialogs();
  const { signOut } = useAuthActions();
  const { t } = useLanguage();
  const onItemClick = useCallback(() => {
    confirm({
      title: t('退出登录', 'Log out'),
      message: t('确定退出西电知行吗？', 'Are you sure you want to log out of Zhixing?'),
      onConfirm: () => signOut({ callbackUrl: '/' }),
    });
  }, [confirm, signOut, t]);
  const className = cn(
    'group relative flex h-12 w-full cursor-pointer items-center justify-center gap-0 rounded-full px-3 text-foreground transition-colors hover:bg-secondary md:justify-center xl:justify-start xl:gap-4 xl:px-4',
    mobileTab && 'h-14 flex-1 flex-col gap-0.5 rounded-md px-1 hover:bg-transparent',
    isActive && !mobileTab && 'bg-secondary/80 font-semibold',
    isActive && mobileTab && 'text-primary',
  );
  const contents = (
    <>
      <span
        className={cn(
          'absolute left-1 hidden h-7 w-[3px] rounded-full bg-primary xl:block',
          !isActive && 'scale-y-0 opacity-0',
        )}
      />
      <span className={cn('relative grid h-8 w-8 shrink-0 place-items-center rounded-full', mobileTab && 'h-6 w-7')}>
        <Icon className={cn('h-[22px] w-[22px] shrink-0 stroke-current', isActive && 'stroke-[2.4px]')} />
        {badge !== undefined && badge !== 0 ? (
          <span className="absolute -right-2 -top-1">
            <Badge>{badge}</Badge>
          </span>
        ) : null}
      </span>
      <span
        className={cn('hidden text-[17px] leading-6 xl:block', mobileTab && 'block text-[10px] leading-3 md:hidden')}>
        {children}
      </span>
    </>
  );

  // The admin console is a separate (Flutter) app: a full page load, not a client route.
  if (route.startsWith('/admin/')) {
    return (
      <a href={route} aria-label={children as string} className={className}>
        {contents}
      </a>
    );
  }

  if (route === '/api/auth/signout') {
    return (
      <ButtonNaked aria-label={children as string} className={className} onPress={onItemClick}>
        {contents}
      </ButtonNaked>
    );
  }

  return (
    <Link
      href={route}
      prefetch={false}
      aria-label={children as string}
      aria-current={isActive ? 'page' : undefined}
      className={cn(
        className,
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2',
      )}
      onMouseEnter={() => router.prefetch(route)}
      onFocus={() => router.prefetch(route)}>
      {contents}
    </Link>
  );
}
