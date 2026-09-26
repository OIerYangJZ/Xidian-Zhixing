import { ProfilePhoto } from '@/components/ui/ProfilePhoto';
import { ActivityType } from '@prisma/client';
/* eslint-disable import/no-duplicates */
import { formatDistanceToNowStrict } from 'date-fns';
import { zhCN } from 'date-fns/locale';
import React, { ComponentProps, useRef } from 'react';
import { UserSummaryAfterSetUp } from '@/types/definitions';
import { mergeProps, useFocusRing, useLink } from 'react-aria';
import { cn } from '@/lib/cn';
import { ActivityIcon } from './ActivityIcon';

interface ActivityCardProps extends ComponentProps<'div'> {
  children: React.ReactNode;
  user: UserSummaryAfterSetUp;
  date: Date;
  type: ActivityType;
  isRead: boolean;
}

export function ActivityCard({ children, user, date, type, isRead, ...rest }: ActivityCardProps) {
  const ref = useRef(null);
  const { linkProps } = useLink({ elementType: 'div' }, ref);
  const { isFocusVisible, focusProps } = useFocusRing();

  return (
    <div
      {...mergeProps(linkProps, focusProps)}
      ref={ref}
      className={cn(
        'feed-separator flex min-h-[88px] cursor-pointer gap-3 border-b px-4 py-4 transition-colors hover:bg-foreground/[0.025] focus:outline-none sm:px-5',
        isFocusVisible && 'ring-2 ring-inset ring-primary',
      )}
      aria-label="查看互动"
      {...rest}>
      <div className="relative h-11 w-11 shrink-0">
        <ProfilePhoto name={user.name} username={user.username} photoUrl={user.profilePhoto} />
        <ActivityIcon type={type} />
      </div>

      <div className="my-auto min-w-0 flex-1">
        <p className="text-[14px] leading-5">{children}</p>
        <p className="mt-1 text-xs text-muted-foreground">
          {formatDistanceToNowStrict(date, { addSuffix: true, locale: zhCN })}
        </p>
      </div>

      {!isRead && (
        <div className="grid place-items-center">
          <div className="h-2.5 w-2.5 rounded-full bg-primary" />
        </div>
      )}
    </div>
  );
}
