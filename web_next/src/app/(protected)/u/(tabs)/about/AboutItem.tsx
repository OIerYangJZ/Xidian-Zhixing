import { SVGProps } from 'react';
import { useLanguage } from '@/hooks/useLanguage';

export function AboutItem({
  field,
  value,
  Icon,
}: {
  field: string;
  value: string | null;
  Icon: (props: SVGProps<SVGSVGElement>) => JSX.Element;
}) {
  const { t } = useLanguage();
  return (
    <div className="feed-separator flex items-start gap-3 border-b px-4 py-4 sm:px-5">
      <Icon className="mt-0.5 h-5 w-5 shrink-0 stroke-primary" />
      <div className="min-w-0 flex-1">
        <p className="text-xs font-medium text-muted-foreground">{field}</p>
        <p className="mt-1 break-words text-sm font-medium text-foreground">{value || t('未填写', 'Not provided')}</p>
      </div>
    </div>
  );
}
