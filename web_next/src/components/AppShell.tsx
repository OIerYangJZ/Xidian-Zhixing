import { ReactNode } from 'react';
import { MobileTopBar } from './MobileTopBar';
import { RightRail } from './RightRail';
import { MenuBar } from './MenuBar';
import { ResponsiveContainer } from './ui/ResponsiveContainer';

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-dvh bg-background">
      <div className="mx-auto min-h-dvh w-full max-w-[1280px] md:grid md:grid-cols-[72px_minmax(0,640px)] xl:grid-cols-[var(--sidebar-width)_minmax(0,var(--content-width))_var(--right-rail-width)] xl:gap-x-6">
        <MenuBar />
        <div className="min-w-0 md:border-x md:border-border xl:border-0">
          <MobileTopBar />
          <ResponsiveContainer className="pb-24 md:pb-10">{children}</ResponsiveContainer>
        </div>
        <RightRail />
      </div>
    </div>
  );
}
