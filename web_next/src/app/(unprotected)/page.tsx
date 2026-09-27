'use client';

import { useLanguage } from '@/hooks/useLanguage';

export default function Page() {
  const { language } = useLanguage();
  return (
    <iframe
      title={language === 'en' ? 'Xidian Zhixing home' : '西电知行首页'}
      src={`/zhixing-home/index.html?lang=${language}`}
      className="fixed inset-0 z-50 h-dvh w-full border-0 bg-white"
    />
  );
}
