'use client';

import { TextInput } from '@/components/ui/TextInput';
import SvgSearch from '@/svg_components/Search';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useCallback } from 'react';
import { useLanguage } from '@/hooks/useLanguage';

export function DiscoverSearch({ label }: { label?: string }) {
  const { t } = useLanguage();
  const router = useRouter();
  const searchParams = useSearchParams();
  const pathname = usePathname();

  const handleChange = useCallback(
    (search: string) => {
      const params = new URLSearchParams(searchParams);
      if (search === '') {
        params.delete('search');
      } else {
        params.set('search', search);
      }

      const url = `${pathname}?${params.toString()}`;
      router.replace(url, { scroll: false });
    },
    [pathname, router, searchParams],
  );

  return (
    <div className="mb-3">
      <TextInput
        onChange={handleChange}
        label={label || t('搜索同学、帖子和话题', 'Search people, posts, and topics')}
        Icon={SvgSearch}
      />
    </div>
  );
}
