'use client';

import { DropdownMenuButton } from '@/components/ui/DropdownMenuButton';
import { HamburgerMenu } from '@/svg_components';
import { useSession } from 'next-auth/react';
import { useRouter } from 'next/navigation';
import { Key, useCallback, useMemo } from 'react';
import { Item, Section } from 'react-stately';

export function HomeMobileDropdownMenu() {
  const router = useRouter();
  const { data: session } = useSession();
  const isLoggedIn = !!session?.user;

  const onAction = useCallback((key: Key) => router.push(key as string), [router]);

  const menuItems = useMemo(() => {
    const items = [
      { key: '/campus', label: '校园服务' },
      { key: '/terms', label: '使用条款' },
      { key: '/privacy-policy', label: '隐私说明' },
    ];

    if (!isLoggedIn) {
      items.push({ key: '/login', label: '登录' });
    } else {
      items.push({ key: '/feed', label: '进入知行' });
    }

    return items;
  }, [isLoggedIn]);

  return (
    <DropdownMenuButton key="home-dropdown-menu" label="页面菜单" onAction={onAction} Icon={HamburgerMenu}>
      <Section>
        {menuItems.map((item) => (
          <Item key={item.key}>{item.label}</Item>
        ))}
      </Section>
    </DropdownMenuButton>
  );
}
