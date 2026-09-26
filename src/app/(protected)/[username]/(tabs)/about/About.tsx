'use client';

import { AtSign, Bullhorn, Profile, WorldNet } from '@/svg_components';
import { GetUser } from '@/types/definitions';
import { useLanguage } from '@/hooks/useLanguage';
import { AboutItem } from './AboutItem';

export function About({ profile }: { profile: GetUser }) {
  const { t } = useLanguage();
  const { username, name, bio, website } = profile;
  return (
    <div className="flex flex-col gap-4">
      <AboutItem field={t('用户名', 'Username')} value={username} Icon={AtSign} />
      <AboutItem field={t('昵称', 'Name')} value={name} Icon={Profile} />
      <AboutItem field={t('个人介绍', 'Bio')} value={bio} Icon={Bullhorn} />
      <AboutItem field={t('个人网站', 'Website')} value={website} Icon={WorldNet} />
    </div>
  );
}
