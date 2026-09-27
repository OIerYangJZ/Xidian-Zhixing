'use client';

import { CreatePostModalContextProvider } from '@/contexts/CreatePostModalContext';
import { DialogsContextProvider } from '@/contexts/DialogsContext';
import { ReactQueryProvider } from '@/contexts/ReactQueryProvider';
import { ShouldAnimateContextProvider } from '@/contexts/ShouldAnimateContext';
import { ThemeContextProvider } from '@/contexts/ThemeContext';
import { LanguageContextProvider } from '@/contexts/LanguageContext';
import { ToastContextProvider } from '@/contexts/ToastContext';
import { VisualMediaModalContextProvider } from '@/contexts/VisualMediaModalContext';
import { SessionProvider } from '@/lib/backend/session';
import React from 'react';

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <LanguageContextProvider>
      <ThemeContextProvider>
        <ToastContextProvider>
          <ReactQueryProvider>
            <SessionProvider>
              <DialogsContextProvider>
                <VisualMediaModalContextProvider>
                  <CreatePostModalContextProvider>
                    <ShouldAnimateContextProvider>{children}</ShouldAnimateContextProvider>
                  </CreatePostModalContextProvider>
                </VisualMediaModalContextProvider>
              </DialogsContextProvider>
            </SessionProvider>
          </ReactQueryProvider>
        </ToastContextProvider>
      </ThemeContextProvider>
    </LanguageContextProvider>
  );
}
