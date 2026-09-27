import React from 'react';
import { cn } from '@/lib/cn';

export function PageHeader({
  title,
  action,
  sticky = false,
  className,
}: {
  title: string;
  action?: React.ReactNode;
  sticky?: boolean;
  className?: string;
}) {
  return (
    <header
      className={cn(
        'page-header feed-separator border-b px-4 py-3.5 sm:px-5',
        sticky && 'sticky top-14 z-20 bg-background/90 backdrop-blur-xl md:top-0',
        className,
      )}>
      <div className="flex items-center justify-between gap-4">
        <h1 className="truncate text-lg font-bold tracking-tight">{title}</h1>
        {action && <div className="shrink-0">{action}</div>}
      </div>
    </header>
  );
}
