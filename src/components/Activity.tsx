import { GetActivity } from '@/types/definitions';
import { SemiBold } from '@/components/ui/SemiBold';
import { useSession } from 'next-auth/react';
import { useRouter } from 'next/navigation';
import { useNotificationsReadStatusMutations } from '@/hooks/mutations/useNotificationsReadStatusMutations';
import { ActivityCard } from './ActivityCard';

/** Use this component to render individual activities or notifications. */
export function Activity({
  id,
  type,
  sourceId,
  sourceUser,
  targetId,
  targetUser,
  createdAt,
  isNotificationRead,
  content,
}: GetActivity) {
  const { data: session } = useSession();
  const userId = session?.user.id;
  const router = useRouter();
  const { markAsReadMutation } = useNotificationsReadStatusMutations();

  // If this is an activity, the `sourceUser.id` is guaranteed to equal the `userId`.
  const isActivity = sourceUser.id === userId;
  const isNotification = targetUser.id === userId;
  const userToDisplay = isActivity ? targetUser : sourceUser;

  const sourceProperNoun = isActivity ? '你' : sourceUser.name;
  const sourcePossessiveNoun = isActivity ? '你的' : `${sourceUser.name}的`;

  const targetProperNoun = isNotification ? '你' : targetUser.name;
  const targetPossessiveNoun = isNotification ? '你的' : `${targetUser.name}的`;

  const isRead = isActivity || isNotificationRead;
  const navigate = (href: string) => () => {
    router.push(href);

    // Set the notification as read
    if (!isNotification) return;
    markAsReadMutation.mutate({ notificationId: id });
  };

  if (type === 'CREATE_FOLLOW') {
    return (
      <ActivityCard
        type={type}
        user={userToDisplay}
        date={new Date(createdAt)}
        isRead={isRead}
        onClick={navigate(`/${isActivity ? targetUser.username : sourceUser.username}`)}>
        <SemiBold>{sourceProperNoun}</SemiBold> 关注了 <SemiBold>{targetProperNoun}</SemiBold>
      </ActivityCard>
    );
  }

  if (type === 'POST_LIKE') {
    return (
      <ActivityCard
        type={type}
        user={userToDisplay}
        date={new Date(createdAt)}
        isRead={isRead}
        onClick={navigate(`/posts/${targetId}`)}>
        <SemiBold>{sourceProperNoun}</SemiBold> 赞了 <SemiBold>{targetPossessiveNoun}</SemiBold>动态：「{content}」
      </ActivityCard>
    );
  }
  if (type === 'POST_MENTION') {
    return (
      <ActivityCard
        type={type}
        user={userToDisplay}
        date={new Date(createdAt)}
        isRead={isRead}
        onClick={navigate(`/posts/${sourceId}`)}>
        <SemiBold>{sourceProperNoun}</SemiBold> 在{sourcePossessiveNoun}动态中提到了{' '}
        <SemiBold>{targetProperNoun}</SemiBold>：「{content}」
      </ActivityCard>
    );
  }

  if (type === 'CREATE_COMMENT') {
    return (
      <ActivityCard
        type={type}
        user={userToDisplay}
        date={new Date(createdAt)}
        isRead={isRead}
        onClick={navigate(`/comments/${sourceId}`)}>
        <SemiBold>{sourceProperNoun}</SemiBold> 评论了 <SemiBold>{targetPossessiveNoun}</SemiBold>动态：「{content}」
      </ActivityCard>
    );
  }
  if (type === 'COMMENT_LIKE') {
    return (
      <ActivityCard
        type={type}
        user={userToDisplay}
        date={new Date(createdAt)}
        isRead={isRead}
        onClick={navigate(`/comments/${targetId}`)}>
        <SemiBold>{sourceProperNoun}</SemiBold> 赞了 <SemiBold>{targetPossessiveNoun}</SemiBold>评论：「{content}」
      </ActivityCard>
    );
  }
  if (type === 'COMMENT_MENTION') {
    return (
      <ActivityCard
        type={type}
        user={userToDisplay}
        date={new Date(createdAt)}
        isRead={isRead}
        onClick={navigate(`/comments/${sourceId}`)}>
        <SemiBold>{sourceProperNoun}</SemiBold> 在{sourcePossessiveNoun}评论中提到了{' '}
        <SemiBold>{targetProperNoun}</SemiBold>：「{content}」
      </ActivityCard>
    );
  }

  if (type === 'CREATE_REPLY') {
    return (
      <ActivityCard
        type={type}
        user={userToDisplay}
        date={new Date(createdAt)}
        isRead={isRead}
        onClick={navigate(`/comments/${sourceId}`)}>
        <SemiBold>{sourceProperNoun}</SemiBold> 回复了 <SemiBold>{targetPossessiveNoun}</SemiBold>评论：「{content}」
      </ActivityCard>
    );
  }
  if (type === 'REPLY_LIKE') {
    return (
      <ActivityCard
        type={type}
        user={userToDisplay}
        date={new Date(createdAt)}
        isRead={isRead}
        onClick={navigate(`/comments/${targetId}`)}>
        <SemiBold>{sourceProperNoun}</SemiBold> 赞了 <SemiBold>{targetPossessiveNoun}</SemiBold>回复：「{content}」
      </ActivityCard>
    );
  }
  if (type === 'REPLY_MENTION') {
    return (
      <ActivityCard
        type={type}
        user={userToDisplay}
        date={new Date(createdAt)}
        isRead={isRead}
        onClick={navigate(`/comments/${sourceId}`)}>
        <SemiBold>{sourceProperNoun}</SemiBold> 在{sourcePossessiveNoun}回复中提到了{' '}
        <SemiBold>{targetProperNoun}</SemiBold>：「{content}」
      </ActivityCard>
    );
  }

  return null;
}
