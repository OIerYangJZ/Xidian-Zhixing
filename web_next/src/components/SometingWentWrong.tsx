'use client';

import { CircleActionsAlertInfo } from '@/svg_components';
import { useLanguage } from '@/hooks/useLanguage';

export function SomethingWentWrong() {
  const { t } = useLanguage();
  return (
    <div className="mt-6 grid place-items-center">
      <div className="inline-block rounded-md bg-destructive px-8 py-6">
        <div className="flex items-center gap-4">
          <CircleActionsAlertInfo className="stroke-destructive-foreground" width={24} height={24} />
          <p className="text-sm font-semibold text-destructive-foreground">
            {t('出了点问题，请稍后重试。', 'Something went wrong. Please try again.')}
          </p>
        </div>
      </div>
    </div>
  );
}
