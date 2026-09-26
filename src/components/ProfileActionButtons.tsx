'use client';

import Button from '@/components/ui/Button';
import { useFollowsMutations } from '@/hooks/mutations/useFollowsMutations';
import { useUserQuery } from '@/hooks/queries/useUserQuery';
import { useCallback } from 'react';
import { useLanguage } from '@/hooks/useLanguage';

export function ProfileActionButtons({ targetUserId }: { targetUserId: string }) {
  const { data: targetUser, isPending } = useUserQuery(targetUserId);
  const { t } = useLanguage();
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

  return (
    <div className="flex flex-row items-center gap-2 md:gap-4">
      <Button onPress={handleClick} mode={isFollowing ? 'secondary' : 'primary'} shape="pill" loading={isPending}>
        {isFollowing ? t('已关注', 'Following') : t('关注', 'Follow')}
      </Button>
      {/* <Button Icon={Mail} onPress={() => {}} mode="secondary" size="medium" /> */}
    </div>
  );
}
