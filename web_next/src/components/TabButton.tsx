import { cn } from '@/lib/cn';
import Link from 'next/link';

export function TabButton({ isActive, title, href }: { isActive?: boolean; title: string; href: string }) {
  return (
    <Link
      aria-label={title}
      className="flex min-w-0 flex-1 cursor-pointer flex-col items-center gap-2 px-2 pt-1"
      href={href}>
      <h2
        className={cn(
          'truncate text-sm',
          isActive ? 'font-semibold text-foreground' : 'font-medium text-muted-foreground hover:text-foreground',
        )}>
        {title}
      </h2>
      {isActive && <div className="h-[2px] w-full bg-foreground" />}
    </Link>
  );
}
