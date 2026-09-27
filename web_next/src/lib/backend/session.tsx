'use client';

/**
 * Session state for the static site, shaped like the slice of next-auth/react
 * the components use: `useSession()` → `{ data: { user: { id, name, role } },
 * status }`, plus `signOut()`.
 *
 * The bearer token lives in localStorage (./token).  After sign-in, and once
 * per page load, the token is also mirrored into the HttpOnly `zx_session`
 * cookie via POST /api/auth/web-session so Nginx can gate signed-in pages on
 * the server (auth_request → GET /api/auth/check).  If that cookie is lost
 * while the token is still good, the reload heals it.
 */
import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api, ApiError, setUnauthorizedHandler } from './client';
import { clearToken, getToken, setToken } from './token';
import type { ApiMe } from './types';

type Status = 'loading' | 'authenticated' | 'unauthenticated';

export interface Session {
  user: { id: string; name: string; role?: 'ADMIN' | 'USER' };
}

interface SessionContextValue {
  status: Status;
  me: ApiMe | null;
  refresh: () => Promise<void>;
  signInWithToken: (token: string) => Promise<ApiMe | null>;
  signOut: (options?: { callbackUrl?: string }) => Promise<void>;
}

const SessionContext = createContext<SessionContextValue | null>(null);

async function mirrorTokenIntoCookie() {
  try {
    await api<null>('/api/auth/web-session', { method: 'POST' });
  } catch {
    // The gate cookie is a convenience for Nginx; the API still works without it.
  }
}

export function loginUrl(from?: string) {
  const target = from ?? (typeof window === 'undefined' ? '/' : window.location.pathname + window.location.search);
  return target && target !== '/' && !target.startsWith('/login') ? `/login?from=${encodeURIComponent(target)}` : '/login';
}

export function SessionProvider({ children }: { children: React.ReactNode }) {
  const [status, setStatus] = useState<Status>('loading');
  const [me, setMe] = useState<ApiMe | null>(null);

  const loadMe = useCallback(async (): Promise<ApiMe | null> => {
    if (!getToken()) {
      setMe(null);
      setStatus('unauthenticated');
      return null;
    }
    try {
      const user = await api<ApiMe>('/api/users/me');
      setMe(user);
      setStatus('authenticated');
      return user;
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        setMe(null);
        setStatus('unauthenticated');
        return null;
      }
      // Network trouble: keep the token and let the pages retry.
      setStatus(getToken() ? 'authenticated' : 'unauthenticated');
      return null;
    }
  }, []);

  useEffect(() => {
    setUnauthorizedHandler(() => {
      setMe(null);
      setStatus('unauthenticated');
      fetch('/api/auth/web-session', { method: 'DELETE' }).catch(() => {});
      window.location.assign(loginUrl());
    });
    if (getToken()) mirrorTokenIntoCookie();
    loadMe();
    return () => setUnauthorizedHandler(null);
  }, [loadMe]);

  const signInWithToken = useCallback(
    async (token: string) => {
      setToken(token);
      await mirrorTokenIntoCookie();
      return loadMe();
    },
    [loadMe],
  );

  const signOut = useCallback(async ({ callbackUrl = '/login' }: { callbackUrl?: string } = {}) => {
    try {
      await api('/api/auth/logout', { method: 'POST' });
    } catch {
      // The session may already be gone; signing out locally is what matters.
    }
    await fetch('/api/auth/web-session', { method: 'DELETE' }).catch(() => {});
    clearToken();
    setMe(null);
    setStatus('unauthenticated');
    window.location.assign(callbackUrl);
  }, []);

  const value = useMemo(
    () => ({ status, me, refresh: async () => void (await loadMe()), signInWithToken, signOut }),
    [status, me, loadMe, signInWithToken, signOut],
  );
  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

function useSessionContext(): SessionContextValue {
  const context = useContext(SessionContext);
  if (!context) throw new Error('useSession must be used inside <SessionProvider>');
  return context;
}

/** next-auth compatible: `const { data: session, status } = useSession()`. */
export function useSession(): { data: Session | null; status: Status } {
  const { status, me } = useSessionContext();
  const data = useMemo<Session | null>(
    () =>
      me
        ? { user: { id: me.id, name: me.nickname || me.alias, role: me.isAdmin ? 'ADMIN' : 'USER' } }
        : null,
    [me],
  );
  return { data, status };
}

/** The full /api/users/me payload (ban state, preferences, counts). */
export function useMe() {
  const { me, status, refresh } = useSessionContext();
  return { me, status, refresh };
}

export function useAuthActions() {
  const { signInWithToken, signOut } = useSessionContext();
  return { signInWithToken, signOut };
}
