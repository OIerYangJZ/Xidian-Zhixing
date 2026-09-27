import { GetActivity } from '@/types/definitions';
import { SemiBold } from '@/components/ui/SemiBold';
import { useRouter } from 'next/navigation';
import { useNotificationsReadStatusMutations } from '@/hooks/mutations/useNotificationsReadStatusMutations';
import { useLanguage } from '@/hooks/useLanguage';
import { postHref } from '@/lib/profileHref';
import { ActivityCard } from './ActivityCard';

/** One notification.  The backend already writes its title and quote. */
export function Activity({ id, type, sourceUser, targetId, postId, createdAt, isNotificationRead, title, content }: GetActivity) {
  const { t } = useLanguage();
  const router = useRouter();
  const { markAsReadMutation } = useNotificationsReadStatusMutations();

  const verbs: Partial<Record<GetActivity['type'], string>> = {
    POST_LIKE: t('赞了你的帖子', 'liked your post'),
    POST_FAVORITE: t('收藏了你的帖子', 'saved your post'),
    CREATE_COMMENT: t('评论了你的帖子', 'commented on your post'),
    COMMENT_LIKE: t('赞了你的评论', 'liked your comment'),
    CREATE_REPLY: t('回复了你的评论', 'replied to your comment'),
  };
  const verb = verbs[type];

  const open = () => {
    if (!isNotificationRead) markAsReadMutation.mutate({ notificationId: id });
    if (postId) router.push(postHref(postId, targetId || undefined));
  };

  return (
    <ActivityCard type={type} user={sourceUser} date={new Date(createdAt)} isRead={isNotificationRead} onClick={open}>
      {verb ? (
        <>
          <SemiBold>{sourceUser.name}</SemiBold> {verb}
          {content && <span className="text-muted-foreground">：“{content}”</span>}
        </>
      ) : (
        <>
          <SemiBold>{title || t('系统通知', 'Notice')}</SemiBold>
          {content && <span className="block text-muted-foreground">{content}</span>}
        </>
      )}
    </ActivityCard>
  );
}
