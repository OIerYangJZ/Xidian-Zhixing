'use client';

import { useLanguage } from '@/hooks/useLanguage';

export function CommentMissing() {
  const { t } = useLanguage();
  return (
    <p className="px-4 py-6 text-sm text-muted-foreground">
      {t('这条评论或回复已不存在。', 'This comment or reply no longer exists.')}
    </p>
  );
}
