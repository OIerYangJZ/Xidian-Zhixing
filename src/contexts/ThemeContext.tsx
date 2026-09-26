'use client';

import React, { createContext, useCallback, useEffect, useMemo, useState } from 'react';

type Themes = 'system' | 'light' | 'dark';
export type VisualTheme = 'zhixing' | 'editorial';
export const ThemeContext = createContext<{
  theme: Themes;
  handleThemeChange: (theme: Themes) => void;
  visualTheme: VisualTheme;
  handleVisualThemeChange: (theme: VisualTheme) => void;
}>({ theme: 'system', handleThemeChange: () => {}, visualTheme: 'zhixing', handleVisualThemeChange: () => {} });

const LS_THEME_KEY = 'theme';
const LS_VISUAL_THEME_KEY = 'zhixing-visual-theme';
export function ThemeContextProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<Themes>('system');
  const [visualTheme, setVisualTheme] = useState<VisualTheme>('zhixing');

  const setToDarkTheme = useCallback(() => {
    document.documentElement.classList.add('dark');
  }, []);
  const setToLightTheme = useCallback(() => {
    document.documentElement.classList.remove('dark');
  }, []);
  const handleThemeChange = useCallback(
    (themeValue: Themes) => {
      localStorage.setItem(LS_THEME_KEY, themeValue);
      setTheme(themeValue);
      if (themeValue === 'dark') setToDarkTheme();
      if (themeValue === 'light') setToLightTheme();
      if (themeValue === 'system' && window.matchMedia) {
        if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
          setToDarkTheme();
        } else {
          setToLightTheme();
        }
      }
    },
    [setToDarkTheme, setToLightTheme],
  );
  const handleVisualThemeChange = useCallback((themeValue: VisualTheme) => {
    localStorage.setItem(LS_VISUAL_THEME_KEY, themeValue);
    document.documentElement.dataset.visualTheme = themeValue;
    setVisualTheme(themeValue);
  }, []);
  const value = useMemo(
    () => ({ theme, handleThemeChange, visualTheme, handleVisualThemeChange }),
    [theme, handleThemeChange, visualTheme, handleVisualThemeChange],
  );

  useEffect(() => {
    // Defaults to 'system' if there's no saved theme
    const savedTheme = (localStorage.getItem(LS_THEME_KEY) || 'system') as Themes;
    handleThemeChange(savedTheme);
    const savedVisualTheme = localStorage.getItem(LS_VISUAL_THEME_KEY);
    handleVisualThemeChange(savedVisualTheme === 'editorial' ? 'editorial' : 'zhixing');
  }, [handleThemeChange, handleVisualThemeChange]);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}
