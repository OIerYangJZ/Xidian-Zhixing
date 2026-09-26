import SvgLoading from '@/svg_components/Loading';
import React from 'react';

export function GenericLoading({ children }: { children?: React.ReactNode }) {
  return (
    <div className="flex flex-col items-center gap-3 py-8">
      <div>
        <SvgLoading className="h-6 w-6 animate-spin stroke-primary" />
      </div>
      <p className="text-sm text-muted-foreground">{children || '正在加载…'}</p>
    </div>
  );
}
