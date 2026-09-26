'use client';

import React, { createContext, useCallback, useEffect, useMemo, useState } from 'react';

export type Language = 'zh' | 'en';
const storageKey = 'zhixing-language';
const cookieKey = 'zhixing-language';

const LanguageContext = createContext<{
  language: Language;
  setLanguage: (language: Language) => void;
}>({ language: 'zh', setLanguage: () => {} });

export function LanguageContextProvider({
  children,
  initialLanguage,
}: {
  children: React.ReactNode;
  initialLanguage: Language;
}) {
  const [language, setLanguageState] = useState(initialLanguage);

  const persistLanguage = useCallback((next: Language) => {
    localStorage.setItem(storageKey, next);
    document.cookie = `${cookieKey}=${next}; Path=/; Max-Age=31536000; SameSite=Lax`;
    document.documentElement.lang = next === 'zh' ? 'zh-CN' : 'en';
    setLanguageState(next);
  }, []);

  useEffect(() => {
    document.documentElement.lang = language === 'zh' ? 'zh-CN' : 'en';
    const hasCookie = document.cookie.split('; ').some((entry) => entry.startsWith(`${cookieKey}=`));
    const savedLanguage = localStorage.getItem(storageKey);
    if (!hasCookie && (savedLanguage === 'zh' || savedLanguage === 'en')) persistLanguage(savedLanguage);
  }, [language, persistLanguage]);

  const value = useMemo(() => ({ language, setLanguage: persistLanguage }), [language, persistLanguage]);
  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguageValue() {
  return React.useContext(LanguageContext);
}
