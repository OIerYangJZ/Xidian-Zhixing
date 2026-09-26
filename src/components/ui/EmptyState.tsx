import React from 'react';
import { cn } from '@/lib/cn';

export function EmptyState({
  title,
  description,
  icon,
  className,
}: {
  title: string;
  description?: string;
  icon?: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      role="status"
      className={cn('flex min-h-48 flex-col items-center justify-center px-6 py-10 text-center', className)}>
      {icon && <div className="mb-3 text-muted-foreground">{icon}</div>}
      <p className="text-sm font-semibold text-foreground">{title}</p>
      {description && <p className="mt-1 max-w-sm text-sm leading-6 text-muted-foreground">{description}</p>}
    </div>
  );
}
