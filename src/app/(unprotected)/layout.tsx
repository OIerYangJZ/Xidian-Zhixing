import { LogoText } from '@/components/LogoText';
import Link from 'next/link';
import React from 'react';
import { getServerUser } from '@/lib/getServerUser';
import { HomeMobileDropdownMenu } from './HomeMobileDropdownMenu';

function HomeNavLink({ children, href }: { children: React.ReactNode; href: string }) {
  return (
    <h3 className="cursor-pointer px-3 py-3 text-sm font-medium text-muted-foreground hover:text-primary">
      <Link href={href}>{children}</Link>
    </h3>
  );
}

export default async function Layout({ children }: { children: React.ReactNode }) {
  const [user] = await getServerUser();
  const isLoggedIn = !!user;

  return (
    <div className="flex min-h-screen w-full justify-center">
      <div className="w-full max-w-6xl gap-3 py-4 sm:py-8">
        <nav className="flex items-center justify-between px-4 sm:px-0">
          <Link href="/" title="西电知行首页">
            <div className="flex cursor-pointer flex-row items-center justify-center gap-2 sm:pr-5">
              <img src="/campus-login/zhixing-logo.jpg" alt="" className="h-9 w-9 rounded-md object-cover" />
              <LogoText className="text-xl text-foreground" />
            </div>
          </Link>
          <div className="hidden gap-3 sm:flex">
            <HomeNavLink href="/campus">校园服务</HomeNavLink>
            <HomeNavLink href="/terms">使用条款</HomeNavLink>
            <HomeNavLink href="/privacy-policy">隐私说明</HomeNavLink>

            {!isLoggedIn && <HomeNavLink href="/login">登录</HomeNavLink>}
            {isLoggedIn && <HomeNavLink href="/feed">进入知行</HomeNavLink>}
          </div>
          <div className="sm:hidden">
            <HomeMobileDropdownMenu />
          </div>
        </nav>

        {children}
      </div>
    </div>
  );
}
