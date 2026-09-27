'use client';

import { usePathname, useRouter } from 'next/navigation';
import React, { useEffect } from 'react';
import { loginUrl, useMe } from '@/lib/backend/session';

/** Where a banned account is sent: the page with the ban notice and appeal form. */
const BANNED_HOME = '/settings/account';

/**
 * Client-side backstop for the signed-in area.  Nginx's auth_request already
 * redirects visitors without a live session before any HTML is sent; this
 * covers local development and a token that dies while a page is open.
 */
export function RequireSession({ children }: { children: React.ReactNode }) {
  const { me, status } = useMe();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (status === 'unauthenticated') router.replace(loginUrl());
  }, [status, router]);

  useEffect(() => {
    if (me?.banned && pathname !== BANNED_HOME) router.replace(BANNED_HOME);
  }, [me?.banned, pathname, router]);

  if (status !== 'authenticated') return null;
  // eslint-disable-next-line react/jsx-no-useless-fragment -- children may be a single string/array
  return <>{children}</>;
}
