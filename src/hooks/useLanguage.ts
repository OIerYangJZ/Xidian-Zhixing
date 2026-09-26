'use client';

import { useCallback } from 'react';
import { useLanguageValue } from '@/contexts/LanguageContext';

export function useLanguage() {
  const { language, setLanguage } = useLanguageValue();
  const t = useCallback((chinese: string, english: string) => (language === 'zh' ? chinese : english), [language]);
  return { language, setLanguage, t };
}
