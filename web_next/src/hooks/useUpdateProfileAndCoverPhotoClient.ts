'use client';

import { useSession } from '@/lib/backend/session';
import React, { useRef } from 'react';
import { useDialogs } from './useDialogs';
import { useToast } from './useToast';
import { useSessionUserDataMutation } from './mutations/useSessionUserDataMutation';

export function useUpdateProfileAndCoverPhotoClient(toUpdate: 'profile' | 'cover') {
  const { data: session } = useSession();
  const userId = session?.user.id;
  const { updateSessionUserPhotosMutation } = useSessionUserDataMutation();
  const { alert } = useDialogs();
  const { showToast } = useToast();
  const inputFileRef = useRef<HTMLInputElement>(null);

  const openInput = () => {
    if (inputFileRef.current == null) return;
    inputFileRef.current.click();
  };

  const handleChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const { files } = e.target;
    if (files === null || !files[0] || !userId) return;
    const file = files[0];

    updateSessionUserPhotosMutation.mutate(
      { toUpdate, file },
      {
        onSuccess: () => {
          showToast({ title: toUpdate === 'profile' ? '头像已更新' : '封面已更新', type: 'success' });
        },
        onError: (error) => {
          alert({ title: '上传失败', message: error instanceof Error ? error.message : '请稍后重试。' });
        },
      },
    );

    if (inputFileRef.current === null) return;
    inputFileRef.current.value = '';
  };

  return {
    inputFileRef,
    openInput,
    handleChange,
    isPending: updateSessionUserPhotosMutation.isPending,
  };
}
