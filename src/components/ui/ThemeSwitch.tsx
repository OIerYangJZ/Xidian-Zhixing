'use client';

import { useTheme } from '@/hooks/useTheme';
import { DeviceLaptop, WeatherMoon, WeatherSun } from '@/svg_components';
import { motion } from 'framer-motion';
import { useMemo } from 'react';

export function ThemeSwitch() {
  const { theme, switchTheme } = useTheme();

  const systemThemeAnimation = useMemo(
    () => ({
      y: theme === 'system' ? 0 : 40,
      opacity: theme === 'system' ? 1 : 0,
    }),
    [theme],
  );
  const lightThemeAnimation = useMemo(
    () => ({
      x: theme === 'light' ? 0 : -30,
      y: theme === 'light' ? 0 : 40,
      opacity: theme === 'light' ? 1 : 0,
    }),
    [theme],
  );
  const darkThemeAnimation = useMemo(
    () => ({
      x: theme === 'dark' ? 0 : 30,
      y: theme === 'dark' ? 0 : 40,
      opacity: theme === 'dark' ? 1 : 0,
    }),
    [theme],
  );
  return (
    <button
      type="button"
      className="relative h-10 w-10 overflow-hidden rounded-full text-muted-foreground transition hover:bg-secondary hover:text-foreground"
      aria-label={`当前主题：${theme === 'system' ? '跟随系统' : theme === 'light' ? '浅色' : '深色'}，点击切换`}
      onClick={switchTheme}>
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
        <motion.div animate={systemThemeAnimation}>
          <DeviceLaptop className="stroke-current" height={20} width={20} />
        </motion.div>
      </div>
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
        <motion.div animate={lightThemeAnimation}>
          <WeatherSun className="stroke-current" height={20} width={20} />
        </motion.div>
      </div>
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
        <motion.div animate={darkThemeAnimation}>
          <WeatherMoon className="stroke-current" height={20} width={20} />
        </motion.div>
      </div>
    </button>
  );
}
