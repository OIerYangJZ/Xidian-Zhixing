'use client';

import Link from 'next/link';
import type { ReactNode } from 'react';
import { useLanguage } from '@/hooks/useLanguage';

function HomeNavLink({ children, href }: { children: ReactNode; href: string }) {
  return (
    <h3 className="cursor-pointer px-3 py-3 text-sm font-medium text-muted-foreground hover:text-primary">
      <Link href={href}>{children}</Link>
    </h3>
  );
}

export function HomeNavigationLinks({ isLoggedIn }: { isLoggedIn: boolean }) {
  const { t } = useLanguage();

  return (
    <div className="hidden gap-3 sm:flex">
      <HomeNavLink href="/campus">{t('校园服务', 'Campus services')}</HomeNavLink>
      <HomeNavLink href="/terms">{t('使用条款', 'Terms')}</HomeNavLink>
      <HomeNavLink href="/privacy-policy">{t('隐私说明', 'Privacy')}</HomeNavLink>
      {!isLoggedIn && <HomeNavLink href="/login">{t('登录', 'Sign in')}</HomeNavLink>}
      {isLoggedIn && <HomeNavLink href="/feed">{t('进入知行', 'Open Zhixing')}</HomeNavLink>}
    </div>
  );
}
