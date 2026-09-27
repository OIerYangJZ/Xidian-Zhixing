'use client';

import { useQueryParam } from '@/hooks/useQueryParam';

/** The profile being viewed: /u?id=<userId>, and the same id on every tab. */
export function useProfileId() {
  return useQueryParam('id');
}
