'use client';

import React, { createContext, useCallback, useEffect, useMemo, useState } from 'react';

export type Language = 'zh' | 'en';
const storageKey = 'zhixing-language';
const cookieKey = 'zhixing-language';

const LanguageContext = createContext<{
  language: Language;
  setLanguage: (language: Language) => void;
}>({ language: 'zh', setLanguage: () => {} });

export function LanguageContextProvider({ children }: { children: React.ReactNode }) {
  // The static HTML is rendered in Chinese; a saved preference is applied
  // right after hydration (the boot script in app/layout already set <html lang>).
  const [language, setLanguageState] = useState<Language>('zh');

  const persistLanguage = useCallback((next: Language) => {
    localStorage.setItem(storageKey, next);
    document.cookie = `${cookieKey}=${next}; Path=/; Max-Age=31536000; SameSite=Lax`;
    document.documentElement.lang = next === 'zh' ? 'zh-CN' : 'en';
    setLanguageState(next);
  }, []);

  useEffect(() => {
    const savedLanguage = localStorage.getItem(storageKey);
    if (savedLanguage === 'zh' || savedLanguage === 'en') setLanguageState(savedLanguage);
  }, []);

  useEffect(() => {
    document.documentElement.lang = language === 'zh' ? 'zh-CN' : 'en';
  }, [language]);

  useEffect(() => {
    const handleLanguageMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin || event.data?.type !== 'zhixing-language-change') return;
      if (event.data.language === 'zh' || event.data.language === 'en') persistLanguage(event.data.language);
    };
    window.addEventListener('message', handleLanguageMessage);
    return () => window.removeEventListener('message', handleLanguageMessage);
  }, [persistLanguage]);

  const value = useMemo(() => ({ language, setLanguage: persistLanguage }), [language, persistLanguage]);
  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguageValue() {
  return React.useContext(LanguageContext);
}
