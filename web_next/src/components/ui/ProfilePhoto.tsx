import Link from 'next/link';
import { profileHref } from '@/lib/profileHref';
import { avatarSrc } from '@/lib/backend/image';
import { FallbackProfilePhoto } from './FallbackProfilePhoto';

export function ProfilePhoto({
  name,
  photoUrl,
  username,
  fallbackAvatarClassName,
}: {
  name: string;
  username: string;
  photoUrl?: string | null;
  fallbackAvatarClassName?: string;
}) {
  const photo = photoUrl ? (
    <img
      src={avatarSrc(photoUrl)}
      alt={`${name}'s avatar`}
      className="h-full w-full cursor-pointer rounded-full bg-muted object-cover"
    />
  ) : (
    <FallbackProfilePhoto name={name} className={fallbackAvatarClassName} />
  );
  const href = profileHref(username);
  // Anonymous authors have no profile to open.
  if (!href) return <div className="block h-full w-full overflow-hidden rounded-full">{photo}</div>;
  return (
    <Link href={href} className="block h-full w-full overflow-hidden rounded-full">
      {photo}
    </Link>
  );
}
