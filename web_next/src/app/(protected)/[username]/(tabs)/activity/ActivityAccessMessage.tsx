'use client';

import { useLanguage } from '@/hooks/useLanguage';

export function ActivityAccessMessage({ reason }: { reason: 'signin' | 'private' }) {
  const { t } = useLanguage();
  return (
    <p className="px-4 py-6 text-sm text-muted-foreground">
      {reason === 'signin'
        ? t('请先登录以查看互动。', 'Sign in to view your activity.')
        : t('你没有权限查看此页面。', 'You do not have permission to view this page.')}
    </p>
  );
}
