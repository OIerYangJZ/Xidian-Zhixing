import Link from 'next/link';
import { profileHref } from '@/lib/profileHref';
import { Avatar } from './Avatar';

/**
 * A user's avatar, linking to their profile.  Without a username (anonymous
 * author, hidden profile) it is the seal and links nowhere.
 */
export function ProfilePhoto({
  name,
  photoUrl,
  username,
  anonymous,
}: {
  name: string;
  username: string;
  photoUrl?: string | null;
  anonymous?: boolean;
}) {
  const href = profileHref(username);
  const isSeal = anonymous ?? !href;
  const avatar = <Avatar name={name} photoUrl={isSeal ? null : photoUrl} anonymous={isSeal} />;
  if (!href || isSeal) return <div className="block h-full w-full">{avatar}</div>;
  return (
    <Link href={href} className="block h-full w-full" aria-label={name}>
      {avatar}
    </Link>
  );
}
