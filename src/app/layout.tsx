import './globals.css';
import 'swiper/css';
import 'swiper/css/zoom';
import 'swiper/css/navigation';
import 'swiper/css/pagination';
import 'react-datepicker/dist/react-datepicker.css';
import { cn } from '@/lib/cn';
import { Providers } from '@/components/Providers';
import { auth } from '@/auth';
import { cookies } from 'next/headers';
import React from 'react';

export const metadata = {
  title: '西电知行',
  description: '连接西电校园生活、社区与服务。',
};

export default async function Layout({ children }: { children: React.ReactNode }) {
  const [session, cookieStore] = await Promise.all([auth(), cookies()]);
  const initialLanguage = cookieStore.get('zhixing-language')?.value === 'en' ? 'en' : 'zh';
  return (
    <html lang={initialLanguage === 'zh' ? 'zh-CN' : 'en'} className="overflow-y-scroll">
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
      </head>
      <body className={cn('bg-background text-foreground')}>
        <Providers session={session} initialLanguage={initialLanguage}>
          {children}
        </Providers>
      </body>
    </html>
  );
}
