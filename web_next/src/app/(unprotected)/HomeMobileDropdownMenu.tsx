'use client';

import { DropdownMenuButton } from '@/components/ui/DropdownMenuButton';
import { HamburgerMenu } from '@/svg_components';
import { useSession } from '@/lib/backend/session';
import { useRouter } from 'next/navigation';
import { Key, useCallback, useMemo } from 'react';
import { Item, Section } from 'react-stately';
import { useLanguage } from '@/hooks/useLanguage';

export function HomeMobileDropdownMenu() {
  const router = useRouter();
  const { t } = useLanguage();
  const { data: session } = useSession();
  const isLoggedIn = !!session?.user;

  const onAction = useCallback((key: Key) => router.push(key as string), [router]);

  const menuItems = useMemo(() => {
    const items = [
      { key: '/campus', label: t('校园服务', 'Campus services') },
      { key: '/terms', label: t('使用条款', 'Terms') },
      { key: '/privacy-policy', label: t('隐私说明', 'Privacy') },
    ];

    if (!isLoggedIn) {
      items.push({ key: '/login', label: t('登录', 'Sign in') });
    } else {
      items.push({ key: '/feed', label: t('进入知行', 'Open Zhixing') });
    }

    return items;
  }, [isLoggedIn, t]);

  return (
    <DropdownMenuButton
      key="home-dropdown-menu"
      label={t('页面菜单', 'Page menu')}
      onAction={onAction}
      Icon={HamburgerMenu}>
      <Section>
        {menuItems.map((item) => (
          <Item key={item.key}>{item.label}</Item>
        ))}
      </Section>
    </DropdownMenuButton>
  );
}
