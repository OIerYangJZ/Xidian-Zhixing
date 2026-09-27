'use client';

import Link from 'next/link';
import { useTheme } from '@/hooks/useTheme';
import { useLanguage } from '@/hooks/useLanguage';
import { PageHeader } from '@/components/ui/PageHeader';
import { useDialogs } from '@/hooks/useDialogs';
import { LogOutCircle } from '@/svg_components';
import { useAuthActions } from '@/lib/backend/session';

export function SettingsPanel() {
  const { theme, handleThemeChange, visualTheme, handleVisualThemeChange, accentColor, handleAccentColorChange } =
    useTheme();
  const { language, setLanguage, t } = useLanguage();
  const { confirm } = useDialogs();
  const { signOut } = useAuthActions();
  const groups = [
    {
      title: t('账号和安全', 'Account and security'),
      description: t('管理个人资料和知行账号。', 'Manage your profile and Zhixing account.'),
      rows: [
        {
          label: t('账号信息与安全', 'Account information and security'),
          detail: t('查看账号信息和安全状态。', 'Review account information and security.'),
          href: '/settings/account',
        },
        {
          label: t('编辑个人资料', 'Edit profile'),
          detail: t('更改头像、名称和个人介绍。', 'Change your photo, name, and bio.'),
          href: '/edit-profile',
        },
      ],
    },
    {
      title: t('隐私和安全', 'Privacy and safety'),
      description: t('管理你在知行上看到和分享的信息。', 'Manage what you see and share on Zhixing.'),
      rows: [
        {
          label: t('受众和私信', 'Audience and direct messages'),
          detail: t('管理私信权限和个人主页可见信息。', 'Manage who can message you and profile visibility.'),
          href: '/settings/privacy',
        },
        {
          label: t('屏蔽账号', 'Blocked accounts'),
          detail: t('管理你屏蔽的账号。', 'Manage accounts you have blocked.'),
          href: '/settings/blocked',
        },
        {
          label: t('隐私说明', 'Privacy policy'),
          detail: t('了解知行如何使用和保护你的信息。', 'Learn how Zhixing uses and protects your information.'),
          href: '/privacy-policy',
        },
      ],
    },
    {
      title: t('通知', 'Notifications'),
      description: t('查看关注、点赞、评论和私信通知。', 'View follow, like, comment, and message notifications.'),
      rows: [
        {
          label: t('通知偏好', 'Notification preferences'),
          detail: t('选择你想收到的通知类型。', 'Choose which notifications you receive.'),
          href: '/settings/notifications',
        },
        {
          label: t('通知中心', 'Notification center'),
          detail: t('打开你的通知。', 'Open your notifications.'),
          href: '/notifications',
        },
      ],
    },
    {
      title: t('辅助功能、显示和语言', 'Accessibility, display, and language'),
      description: t('管理知行的显示方式和界面语言。', 'Choose how Zhixing looks and which language it uses.'),
      rows: [],
    },
    {
      title: t('帮助和关于', 'Help and about'),
      description: t('查看使用条款和知行隐私说明。', 'Read Zhixing terms and privacy information.'),
      rows: [
        {
          label: t('使用条款', 'Terms of service'),
          detail: t('查看知行使用条款。', 'Read the terms of service.'),
          href: '/terms',
        },
        {
          label: t('隐私说明', 'Privacy policy'),
          detail: t('查看隐私说明。', 'Read the privacy policy.'),
          href: '/privacy-policy',
        },
      ],
    },
  ];

  return (
    <div className="min-h-[calc(100dvh-3.5rem)]">
      <PageHeader title={t('设置', 'Settings')} sticky />
      <p className="border-b border-border px-4 py-4 text-sm text-muted-foreground sm:px-5">
        {t('管理你的账号、隐私和知行体验。', 'Manage your account, privacy, and Zhixing experience.')}
      </p>
      {groups.map((group, index) => (
        <section
          key={group.title}
          aria-labelledby={`settings-group-${index}`}
          className="border-b border-border px-4 py-5 sm:px-5">
          <h2 id={`settings-group-${index}`} className="text-base font-semibold">
            {group.title}
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">{group.description}</p>
          {group.rows.length > 0 && (
            <div className="mt-3 divide-y divide-border border-y border-border">
              {group.rows.map((row) => (
                <Link
                  key={row.label}
                  href={row.href}
                  className="flex min-h-14 items-center justify-between gap-4 py-3 hover:text-foreground">
                  <span>
                    <span className="block text-sm font-medium">{row.label}</span>
                    <span className="mt-0.5 block text-xs text-muted-foreground">{row.detail}</span>
                  </span>
                  <span className="text-lg text-muted-foreground" aria-hidden="true">
                    ›
                  </span>
                </Link>
              ))}
            </div>
          )}
          {index === 3 && (
            <div className="mt-4 grid gap-4 sm:grid-cols-2">
              <label className="flex flex-col gap-2 text-sm font-medium">
                {t('视觉风格', 'Visual style')}
                <select
                  aria-label={t('视觉风格', 'Visual style')}
                  value={visualTheme}
                  onChange={(event) => handleVisualThemeChange(event.target.value as 'zhixing' | 'editorial')}
                  className="min-h-11 border border-border bg-background px-3 text-foreground outline-none focus-visible:ring-2 focus-visible:ring-primary">
                  <option value="zhixing">{t('极简', 'Minimal')}</option>
                  <option value="editorial">{t('人本·初创', 'Human-centered · Startup')}</option>
                </select>
              </label>
              <label className="flex flex-col gap-2 text-sm font-medium">
                {t('显示主题', 'Display theme')}
                <select
                  aria-label={t('显示主题', 'Display theme')}
                  value={theme}
                  onChange={(event) => handleThemeChange(event.target.value as 'system' | 'light' | 'dark')}
                  className="min-h-11 border border-border bg-background px-3 text-foreground outline-none focus-visible:ring-2 focus-visible:ring-primary">
                  <option value="system">{t('跟随系统', 'System')}</option>
                  <option value="light">{t('浅色', 'Light')}</option>
                  <option value="dark">{t('深色', 'Dark')}</option>
                </select>
              </label>
              <label className="flex flex-col gap-2 text-sm font-medium">
                {t('高亮颜色', 'Accent color')}
                <span className="flex min-h-11 items-center gap-3 border border-border bg-background px-3">
                  <input
                    type="color"
                    aria-label={t('高亮颜色', 'Accent color')}
                    value={accentColor}
                    onChange={(event) => handleAccentColorChange(event.target.value)}
                    className="h-7 w-10 cursor-pointer border-0 bg-transparent p-0"
                  />
                  <span className="text-xs font-normal text-muted-foreground">{accentColor.toUpperCase()}</span>
                </span>
              </label>
              <label className="flex flex-col gap-2 text-sm font-medium">
                {t('界面语言', 'Interface language')}
                <select
                  aria-label={t('界面语言', 'Interface language')}
                  value={language}
                  onChange={(event) => setLanguage(event.target.value as 'zh' | 'en')}
                  className="min-h-11 border border-border bg-background px-3 text-foreground outline-none focus-visible:ring-2 focus-visible:ring-primary">
                  <option value="zh">{t('简体中文', 'Simplified Chinese')}</option>
                  <option value="en">English</option>
                </select>
              </label>
            </div>
          )}
        </section>
      ))}
      <section className="px-4 py-4 sm:px-5">
        <button
          type="button"
          onClick={() =>
            confirm({
              title: t('退出登录', 'Log out'),
              message: t('确定退出西电知行吗？', 'Are you sure you want to log out of Zhixing?'),
              onConfirm: () => signOut({ callbackUrl: '/' }),
            })
          }
          className="flex min-h-12 w-full items-center gap-3 text-left text-sm text-foreground hover:text-destructive-foreground">
          <LogOutCircle className="h-5 w-5 stroke-current" />
          {t('退出登录', 'Log out')}
        </button>
      </section>
    </div>
  );
}
