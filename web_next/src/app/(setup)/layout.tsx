import React from 'react';
import { AppShell } from '@/components/AppShell';
import { RequireSession } from '@/components/auth/RequireSession';

export default function SetupLayout({ children }: { children: React.ReactNode }) {
  return (
    <RequireSession>
      <AppShell>{children}</AppShell>
    </RequireSession>
  );
}
