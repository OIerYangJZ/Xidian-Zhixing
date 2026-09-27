import { GetActivity } from '@/types/definitions';
import { SemiBold } from '@/components/ui/SemiBold';
import { useSession } from '@/lib/backend/session';
import { useRouter } from 'next/navigation';
import { useNotificationsReadStatusMutations } from '@/hooks/mutations/useNotificationsReadStatusMutations';
import { useLanguage } from '@/hooks/useLanguage';
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
  const { t } = useLanguage();
  const { data: session } = useSession();
  const userId = session?.user.id;
  const router = useRouter();
  const { markAsReadMutation } = useNotificationsReadStatusMutations();

  // If this is an activity, the `sourceUser.id` is guaranteed to equal the `userId`.
  const isActivity = sourceUser.id === userId;
  const isNotification = targetUser.id === userId;
  const userToDisplay = isActivity ? targetUser : sourceUser;

  const sourceProperNoun = isActivity ? t('你', 'You') : sourceUser.name;
  const sourcePossessiveNoun = isActivity ? t('你的', 'your') : t(`${sourceUser.name}的`, `${sourceUser.name}'s`);

  const targetProperNoun = isNotification ? t('你', 'you') : targetUser.name;
  const targetPossessiveNoun = isNotification ? t('你的', 'your') : t(`${targetUser.name}的`, `${targetUser.name}'s`);

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
        <SemiBold>{sourceProperNoun}</SemiBold> {t('关注了', 'followed')} <SemiBold>{targetProperNoun}</SemiBold>
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
        <SemiBold>{sourceProperNoun}</SemiBold> {t('赞了', 'liked')} <SemiBold>{targetPossessiveNoun}</SemiBold>
        {t('动态', ' post')}: “{content}”
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
        <SemiBold>{sourceProperNoun}</SemiBold> {t(`在${sourcePossessiveNoun}动态中提到了`, 'mentioned')}{' '}
        <SemiBold>{targetProperNoun}</SemiBold>
        {t(`：「${content}」`, ` in ${sourcePossessiveNoun} post: “${content}”`)}
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
        <SemiBold>{sourceProperNoun}</SemiBold> {t('评论了', 'commented on')}{' '}
        <SemiBold>{targetPossessiveNoun}</SemiBold>
        {t('动态', ' post')}: “{content}”
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
        <SemiBold>{sourceProperNoun}</SemiBold> {t('赞了', 'liked')} <SemiBold>{targetPossessiveNoun}</SemiBold>
        {t('评论', ' comment')}: “{content}”
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
        <SemiBold>{sourceProperNoun}</SemiBold> {t(`在${sourcePossessiveNoun}评论中提到了`, 'mentioned')}{' '}
        <SemiBold>{targetProperNoun}</SemiBold>
        {t(`：「${content}」`, ` in ${sourcePossessiveNoun} comment: “${content}”`)}
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
        <SemiBold>{sourceProperNoun}</SemiBold> {t('回复了', 'replied to')} <SemiBold>{targetPossessiveNoun}</SemiBold>
        {t('评论', ' comment')}: “{content}”
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
        <SemiBold>{sourceProperNoun}</SemiBold> {t('赞了', 'liked')} <SemiBold>{targetPossessiveNoun}</SemiBold>
        {t('回复', ' reply')}: “{content}”
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
        <SemiBold>{sourceProperNoun}</SemiBold> {t(`在${sourcePossessiveNoun}回复中提到了`, 'mentioned')}{' '}
        <SemiBold>{targetProperNoun}</SemiBold>
        {t(`：「${content}」`, ` in ${sourcePossessiveNoun} reply: “${content}”`)}
      </ActivityCard>
    );
  }

  return null;
}
