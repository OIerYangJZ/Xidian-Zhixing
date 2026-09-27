'use client';

import { DiscoverProfile } from '@/components/DiscoverProfile';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { AnimatePresence, motion } from 'framer-motion';
import { SomethingWentWrong } from '@/components/SometingWentWrong';
import { useShouldAnimate } from '@/hooks/useShouldAnimate';
import { GenericLoading } from '@/components/GenericLoading';
import { useLanguage } from '@/hooks/useLanguage';
import { searchUsers } from '@/lib/backend/endpoints';

const variants = {
  initial: (animate: boolean) => ({ y: animate ? 6 : 0, opacity: animate ? 0 : 1 }),
  animate: { x: 0, y: 0, opacity: 1 },
  exit: { opacity: 0 },
};

/** People whose nickname matches `keyword` (the backend caps this at 50). */
export function DiscoverProfiles({ keyword }: { keyword: string }) {
  const { t } = useLanguage();
  const qc = useQueryClient();
  const { shouldAnimate } = useShouldAnimate();

  const { data, isPending, isError } = useQuery({
    queryKey: ['discover', { keyword }],
    enabled: !!keyword,
    staleTime: 60000,
    queryFn: async () => {
      const users = await searchUsers(keyword);
      // Seed each profile so the rows do not refetch it
      users.forEach((user) => qc.setQueryData(['users', user.id], user));
      return users;
    },
  });

  if (!keyword) return null;
  if (isPending) return <GenericLoading>{t('正在查找同学', 'Finding people')}</GenericLoading>;
  if (isError) return <SomethingWentWrong />;
  if (data.length === 0)
    return (
      <p className="px-4 py-4 text-sm text-muted-foreground sm:px-5">{t('没有找到相关同学。', 'No people found.')}</p>
    );

  return (
    <div className="flex flex-col">
      <AnimatePresence>
        {data.map((profile) => (
          <motion.div
            variants={variants}
            initial="initial"
            animate="animate"
            exit="exit"
            custom={shouldAnimate}
            key={profile.id}>
            <DiscoverProfile userId={profile.id} />
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
