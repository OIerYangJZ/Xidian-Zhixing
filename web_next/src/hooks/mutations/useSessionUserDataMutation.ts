import { UserAboutSchema } from '@/lib/validations/userAbout';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMe, useSession } from '@/lib/backend/session';
import { updateMe, uploadAvatar, uploadImage } from '@/lib/backend/endpoints';
import { useToast } from '../useToast';

/**
 * The signed-in user's own profile: text fields, avatar and cover.  Avatars
 * have a dedicated route; covers are an ordinary upload then a PATCH.
 */
export function useSessionUserDataMutation() {
  const { data: session } = useSession();
  const { refresh } = useMe();
  const userId = session?.user.id;
  const qc = useQueryClient();
  const { showToast } = useToast();

  const afterChange = async () => {
    await Promise.all([qc.invalidateQueries({ queryKey: ['users', userId] }), refresh()]);
  };

  const updateSessionUserDataMutation = useMutation({
    mutationFn: ({ data }: { data: UserAboutSchema }) => updateMe(data),
    onSuccess: async () => {
      await afterChange();
      showToast({ type: 'success', title: '资料已更新' });
    },
  });

  const updateSessionUserPhotosMutation = useMutation({
    mutationFn: async ({ toUpdate, file }: { toUpdate: 'profile' | 'cover'; file: File }) => {
      if (toUpdate === 'profile') return uploadAvatar(file, file.name);
      const upload = await uploadImage(file, file.name);
      if (upload.status !== 'approved') throw new Error(upload.moderationReason || '图片未通过审核');
      return updateMe({ backgroundImageUrl: upload.url });
    },
    onSuccess: afterChange,
  });

  return { updateSessionUserDataMutation, updateSessionUserPhotosMutation };
}
