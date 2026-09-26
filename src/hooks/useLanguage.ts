'use client';

import { useCallback, useEffect, useState } from 'react';

export type Language = 'zh' | 'en';
const storageKey = 'zhixing-language';

export function useLanguage() {
  const [language, setLanguageState] = useState<Language>('zh');
  useEffect(() => {
    document.documentElement.lang = language === 'zh' ? 'zh-CN' : 'en';
    const saved = localStorage.getItem(storageKey);
    if (saved === 'zh' || saved === 'en') setLanguageState(saved);
    const sync = () => {
      const current = localStorage.getItem(storageKey);
      if (current === 'zh' || current === 'en') setLanguageState(current);
    };
    window.addEventListener('zhixing-language-change', sync);
    return () => window.removeEventListener('zhixing-language-change', sync);
  }, [language]);

  const setLanguage = useCallback((next: Language) => {
    localStorage.setItem(storageKey, next);
    document.documentElement.lang = next === 'zh' ? 'zh-CN' : 'en';
    setLanguageState(next);
    window.dispatchEvent(new Event('zhixing-language-change'));
  }, []);
  const t = useCallback((chinese: string, english: string) => (language === 'zh' ? chinese : english), [language]);
  return { language, setLanguage, t };
}
