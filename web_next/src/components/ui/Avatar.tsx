import { type CSSProperties, useMemo } from 'react';
import { cn } from '@/lib/cn';
import { avatarSrc } from '@/lib/backend/image';

/** First character of a name, emoji and surrogate pairs included. */
function initialOf(name: string): string {
  const trimmed = name.trim();
  return trimmed ? Array.from(trimmed)[0] : '?';
}

/** A stable hue per name, so the same person always gets the same tint. */
function hueOf(name: string): number {
  let hash = 0;
  for (const char of name) hash = (hash * 31 + char.codePointAt(0)!) % 360;
  return hash;
}

/**
 * Avatar (§06 头像).  Always a rounded square: the product uses no circles.
 * A real-name account shows its photo, or its first character on a light tint
 * of a stable hue, with a ~24% corner.  An anonymous identity is the seal:
 * solid seal colour, an inner white line like ink paste, ~15% corner.  The
 * fill tells them apart.  Mirrors ZxAvatar in the Flutter app.
 *
 * Sizing comes from the parent box (h-full w-full).
 */
export function Avatar({
  name,
  photoUrl,
  anonymous = false,
  className,
}: {
  name: string;
  photoUrl?: string | null;
  anonymous?: boolean;
  className?: string;
}) {
  const tint = useMemo(() => ({ '--avatar-h': hueOf(name) }) as CSSProperties, [name]);

  if (anonymous) {
    return (
      <div
        role="img"
        aria-label={name}
        className={cn(
          'avatar-seal grid h-full w-full place-items-center overflow-hidden rounded-[15%] bg-primary p-[8%] text-primary-foreground [container-type:size]',
          className,
        )}>
        <span className="grid h-full w-full place-items-center rounded-[9%] border border-white/55 text-[46cqw] leading-none">
          {initialOf(name)}
        </span>
      </div>
    );
  }

  if (photoUrl) {
    return (
      <img
        src={avatarSrc(photoUrl)}
        alt={name}
        className={cn('h-full w-full rounded-[24%] border border-border bg-muted object-cover', className)}
      />
    );
  }

  // The box is the size container; the initial sits in a child so that its
  // cqw font size resolves against the box (container units never refer to
  // the element that declares the container).
  return (
    <div
      role="img"
      aria-label={name}
      style={tint}
      className={cn(
        'avatar-tint grid h-full w-full place-items-center overflow-hidden rounded-[24%] border border-border [container-type:size]',
        className,
      )}>
      <span className="text-[42cqw] font-semibold leading-none">{initialOf(name)}</span>
    </div>
  );
}
