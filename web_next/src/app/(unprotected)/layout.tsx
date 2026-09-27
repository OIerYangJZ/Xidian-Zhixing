'use client';

import { LogoText } from '@/components/LogoText';
import Link from 'next/link';
import React from 'react';
import { useSession } from '@/lib/backend/session';
import { useLanguage } from '@/hooks/useLanguage';
import { HomeMobileDropdownMenu } from './HomeMobileDropdownMenu';
import { HomeNavigationLinks } from './HomeNavigationLinks';

export default function Layout({ children }: { children: React.ReactNode }) {
  const { status } = useSession();
  const isLoggedIn = status === 'authenticated';
  const { language } = useLanguage();

  return (
    <div className="flex min-h-screen w-full justify-center">
      <div className="w-full max-w-6xl gap-3 py-4 sm:py-8">
        <nav className="flex items-center justify-between px-4 sm:px-0">
          <Link href="/" title={language === 'en' ? 'Xidian Zhixing home' : '西电知行首页'}>
            <div className="flex cursor-pointer flex-row items-center justify-center gap-2 sm:pr-5">
              <img src="/campus-login/zhixing-logo.jpg" alt="" className="h-9 w-9 rounded-md object-cover" />
              <LogoText className="text-xl text-foreground" />
            </div>
          </Link>
          <HomeNavigationLinks isLoggedIn={isLoggedIn} />
          <div className="sm:hidden">
            <HomeMobileDropdownMenu />
          </div>
        </nav>

        {children}
      </div>
    </div>
  );
}
