import { AppShell } from '@/components/AppShell';
import { RequireSession } from '@/components/auth/RequireSession';
import React from 'react';

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <RequireSession>
      <AppShell>{children}</AppShell>
    </RequireSession>
  );
}
