import { Skeleton } from './ui/Skeleton';

export function PostSkeleton() {
  return (
    <div role="status" aria-label="正在加载动态" className="feed-separator flex gap-3 border-b px-4 py-4 sm:px-5">
      <Skeleton className="h-10 w-10 shrink-0" />
      <div className="min-w-0 flex-1 space-y-3 pt-1">
        <Skeleton className="h-4 w-2/5" />
        <Skeleton className="h-4 w-full rounded-md" />
        <Skeleton className="h-4 w-4/5 rounded-md" />
        <Skeleton className="mt-4 aspect-[16/9] w-full rounded-lg" />
        <div className="flex justify-between pt-1">
          <Skeleton className="h-7 w-14" />
          <Skeleton className="h-7 w-14" />
          <Skeleton className="h-7 w-14" />
        </div>
      </div>
    </div>
  );
}
