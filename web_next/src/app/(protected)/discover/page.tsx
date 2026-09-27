'use client';

import { Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { DiscoverProfiles } from '@/components/DiscoverProfiles';
import { DiscoverSearch } from '@/components/DiscoverSearch';
import { Posts } from '@/components/Posts';
import { useLanguage } from '@/hooks/useLanguage';
import { DiscoverPageHeader } from './DiscoverPageHeader';

function DiscoverResults() {
  const { t } = useLanguage();
  const keyword = (useSearchParams().get('search') || '').trim();

  if (!keyword)
    return (
      <p className="py-6 text-center text-sm text-muted-foreground">
        {t('输入关键词，搜索同学和帖子。', 'Type to search people and posts.')}
      </p>
    );

  return (
    <>
      <h2 className="mt-2 text-sm font-semibold text-muted-foreground">{t('同学', 'People')}</h2>
      <DiscoverProfiles keyword={keyword} />
      <h2 className="mt-6 text-sm font-semibold text-muted-foreground">{t('帖子', 'Posts')}</h2>
      <Posts type="search" keyword={keyword} />
    </>
  );
}

export default function Discover() {
  return (
    <div>
      <DiscoverPageHeader />
      <div className="px-4 pt-4 sm:px-5">
        <Suspense>
          <DiscoverSearch />
          <DiscoverResults />
        </Suspense>
      </div>
    </div>
  );
}
