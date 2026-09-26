import './globals.css';
import 'swiper/css';
import 'swiper/css/zoom';
import 'swiper/css/navigation';
import 'swiper/css/pagination';
import 'react-datepicker/dist/react-datepicker.css';
import { cn } from '@/lib/cn';
import { Providers } from '@/components/Providers';
import { auth } from '@/auth';
import React from 'react';

export const metadata = {
  title: '西电知行',
  description: '连接西电校园生活、社区与服务。',
};

export default async function Layout({ children }: { children: React.ReactNode }) {
  const session = await auth();
  return (
    <html lang="zh-CN" className="overflow-y-scroll">
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
      </head>
      <body className={cn('bg-background text-foreground')}>
        <Providers session={session}>{children}</Providers>
      </body>
    </html>
  );
}
