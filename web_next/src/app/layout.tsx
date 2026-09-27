import './globals.css';
import 'swiper/css';
import 'swiper/css/zoom';
import 'swiper/css/navigation';
import 'swiper/css/pagination';
import 'react-datepicker/dist/react-datepicker.css';
import { cn } from '@/lib/cn';
import { Providers } from '@/components/Providers';
import React from 'react';

export const metadata = {
  title: '西电知行',
  description: '连接西电校园生活、社区与服务。',
};

/**
 * Runs before first paint, so a saved dark / visual theme / accent colour is
 * applied without a flash of the default look.  The static HTML cannot know
 * these on the server.  Keys match ThemeContext and LanguageContext.
 */
const bootScript = `(function(){try{
var d=document.documentElement,s=localStorage;
var t=s.getItem('theme')||'system';
if(t==='dark'||(t==='system'&&window.matchMedia&&matchMedia('(prefers-color-scheme: dark)').matches))d.classList.add('dark');
d.dataset.visualTheme=s.getItem('zhixing-visual-theme')==='editorial'?'editorial':'zhixing';
var c=s.getItem('zhixing-accent-color');
if(c&&/^#[0-9a-f]{6}$/i.test(c)){var v=parseInt(c.slice(1,3),16)+' '+parseInt(c.slice(3,5),16)+' '+parseInt(c.slice(5,7),16);
['--accent-brand','--primary-accent','--ring'].forEach(function(k){d.style.setProperty(k,v)});}
if(s.getItem('zhixing-language')==='en')d.lang='en';
}catch(e){}})();`;

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN" className="overflow-y-scroll" suppressHydrationWarning>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
        {/* eslint-disable-next-line react/no-danger */}
        <script dangerouslySetInnerHTML={{ __html: bootScript }} />
      </head>
      <body className={cn('bg-background text-foreground')}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
