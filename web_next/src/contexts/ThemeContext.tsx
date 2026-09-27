'use client';

import React, { createContext, useCallback, useEffect, useMemo, useState } from 'react';

type Themes = 'system' | 'light' | 'dark';
export type VisualTheme = 'zhixing' | 'editorial';
const DEFAULT_ACCENT_COLOR = '#cb0305';
export const ThemeContext = createContext<{
  theme: Themes;
  handleThemeChange: (theme: Themes) => void;
  visualTheme: VisualTheme;
  handleVisualThemeChange: (theme: VisualTheme) => void;
  accentColor: string;
  handleAccentColorChange: (color: string) => void;
}>({
  theme: 'system',
  handleThemeChange: () => {},
  visualTheme: 'zhixing',
  handleVisualThemeChange: () => {},
  accentColor: DEFAULT_ACCENT_COLOR,
  handleAccentColorChange: () => {},
});

const LS_THEME_KEY = 'theme';
const LS_VISUAL_THEME_KEY = 'zhixing-visual-theme';
const LS_ACCENT_COLOR_KEY = 'zhixing-accent-color';
export function ThemeContextProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<Themes>('system');
  const [visualTheme, setVisualTheme] = useState<VisualTheme>('zhixing');
  const [accentColor, setAccentColor] = useState(DEFAULT_ACCENT_COLOR);

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
  const handleAccentColorChange = useCallback((color: string) => {
    const red = Number.parseInt(color.slice(1, 3), 16);
    const green = Number.parseInt(color.slice(3, 5), 16);
    const blue = Number.parseInt(color.slice(5, 7), 16);
    document.documentElement.style.setProperty('--accent-brand', `${red} ${green} ${blue}`);
    document.documentElement.style.setProperty('--primary-accent', `${red} ${green} ${blue}`);
    document.documentElement.style.setProperty('--ring', `${red} ${green} ${blue}`);
    localStorage.setItem(LS_ACCENT_COLOR_KEY, color);
    setAccentColor(color);
  }, []);
  const value = useMemo(
    () => ({ theme, handleThemeChange, visualTheme, handleVisualThemeChange, accentColor, handleAccentColorChange }),
    [theme, handleThemeChange, visualTheme, handleVisualThemeChange, accentColor, handleAccentColorChange],
  );

  useEffect(() => {
    // Defaults to 'system' if there's no saved theme
    const savedTheme = (localStorage.getItem(LS_THEME_KEY) || 'system') as Themes;
    handleThemeChange(savedTheme);
    const savedVisualTheme = localStorage.getItem(LS_VISUAL_THEME_KEY);
    handleVisualThemeChange(savedVisualTheme === 'editorial' ? 'editorial' : 'zhixing');
    handleAccentColorChange(localStorage.getItem(LS_ACCENT_COLOR_KEY) || DEFAULT_ACCENT_COLOR);
  }, [handleThemeChange, handleVisualThemeChange, handleAccentColorChange]);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}
