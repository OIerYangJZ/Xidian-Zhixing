'use client';

import Button from '@/components/ui/Button';
import { useFollowsMutations } from '@/hooks/mutations/useFollowsMutations';
import { useUserQuery } from '@/hooks/queries/useUserQuery';
import { useErrorNotifier } from '@/hooks/useErrorNotifier';
import { useLanguage } from '@/hooks/useLanguage';
import { openDirectConversation } from '@/lib/backend/endpoints';
import { useRouter } from 'next/navigation';
import { useCallback, useState } from 'react';

export function ProfileActionButtons({ targetUserId }: { targetUserId: string }) {
  const { data: targetUser, isPending } = useUserQuery(targetUserId);
  const { t } = useLanguage();
  const router = useRouter();
  const { notifyError } = useErrorNotifier();
  const [opening, setOpening] = useState(false);
  const isFollowing = targetUser?.isFollowing;
  const { followMutation, unFollowMutation } = useFollowsMutations({
    targetUserId,
  });

  const handleClick = useCallback(() => {
    if (isFollowing) {
      unFollowMutation.mutate();
    } else {
      followMutation.mutate();
    }
  }, [isFollowing, followMutation, unFollowMutation]);

  const openChat = useCallback(async () => {
    setOpening(true);
    try {
      const conversation = await openDirectConversation(targetUserId);
      router.push(`/messages?c=${encodeURIComponent(conversation.id)}`);
    } catch (error) {
      notifyError(error, t('无法发起私信', 'Cannot start a chat'));
    } finally {
      setOpening(false);
    }
  }, [notifyError, router, t, targetUserId]);

  return (
    <div className="flex flex-row items-center gap-2 md:gap-4">
      {targetUser?.canDirectMessage && (
        <Button onPress={openChat} mode="secondary" shape="pill" loading={opening}>
          {t('私信', 'Message')}
        </Button>
      )}
      {targetUser?.canFollow !== false && (
        <Button onPress={handleClick} mode={isFollowing ? 'secondary' : 'primary'} shape="pill" loading={isPending}>
          {isFollowing ? t('已关注', 'Following') : t('关注', 'Follow')}
        </Button>
      )}
    </div>
  );
}
