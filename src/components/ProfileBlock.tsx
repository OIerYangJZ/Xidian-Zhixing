import Link from 'next/link';
import { ProfilePhoto } from './ui/ProfilePhoto';

export default function ProfileBlock({
  username,
  name,
  time,
  photoUrl,
  hideAvatar = false,
}: {
  name: string;
  username: string;
  time: string;
  photoUrl: string;
  hideAvatar?: boolean;
}) {
  return (
    <div className={hideAvatar ? 'min-w-0' : 'flex gap-3'}>
      {!hideAvatar && (
        <div className="h-12 w-12 flex-shrink-0">
          <ProfilePhoto photoUrl={photoUrl} username={username} name={name} />
        </div>
      )}

      <div className="min-w-0 pt-0.5">
        <div className="flex min-w-0 flex-wrap items-center gap-x-1.5 gap-y-0.5">
          <h2 className="max-w-full truncate text-sm font-semibold text-foreground">
            <Link href={`/${username}`} className="link">
              {name}
            </Link>
          </h2>
          <span className="truncate text-xs text-muted-foreground">@{username}</span>
          <span className="text-muted-foreground" aria-hidden="true">
            ·
          </span>
          <span className="text-xs text-muted-foreground">{time}</span>
        </div>
      </div>
    </div>
  );
}
