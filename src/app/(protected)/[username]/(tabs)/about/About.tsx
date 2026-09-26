import { AtSign, Bullhorn, Profile, WorldNet } from '@/svg_components';
import { GetUser } from '@/types/definitions';
import { AboutItem } from './AboutItem';

export function About({ profile }: { profile: GetUser }) {
  const { username, name, bio, website } = profile;
  return (
    <div className="flex flex-col gap-4">
      <AboutItem field="用户名" value={username} Icon={AtSign} />
      <AboutItem field="昵称" value={name} Icon={Profile} />
      <AboutItem field="个人介绍" value={bio} Icon={Bullhorn} />
      <AboutItem field="个人网站" value={website} Icon={WorldNet} />
    </div>
  );
}
