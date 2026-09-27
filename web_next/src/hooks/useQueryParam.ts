'use client';

import { useSearchParams } from 'next/navigation';

/**
 * A runtime id from the query string (see src/lib/profileHref.ts for why ids
 * are not path segments).  Pages using this must render inside <Suspense>:
 * a static export cannot know search params at build time.
 */
export function useQueryParam(name: string): string {
  return useSearchParams().get(name) || '';
}
