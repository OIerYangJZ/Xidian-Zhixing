'use client';

import { Controller, SubmitHandler, useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { AtSign, Bullhorn, Profile, WorldNet } from '@/svg_components';
import { UserAboutSchema, userAboutSchema } from '@/lib/validations/userAbout';
import { useSessionUserData } from '@/hooks/useSessionUserData';
import { useSessionUserDataMutation } from '@/hooks/mutations/useSessionUserDataMutation';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo } from 'react';
import { useLanguage } from '@/hooks/useLanguage';
import { GenericLoading } from './GenericLoading';
import { Textarea } from './ui/Textarea';
import Button from './ui/Button';
import { TextInput } from './ui/TextInput';
import { profileHref } from '@/lib/profileHref';

export function EditProfileForm({ redirectTo }: { redirectTo?: string }) {
  const [userData] = useSessionUserData();
  const defaultValues = useMemo(
    () => ({
      username: userData?.username || userData?.id || '',
      name: userData?.name || '',
      bio: userData?.bio || null,
      website: userData?.website || null,
    }),
    [userData],
  );
  const { control, handleSubmit, reset, setError, setFocus } = useForm<UserAboutSchema>({
    resolver: zodResolver(userAboutSchema),
    defaultValues,
  });
  const { updateSessionUserDataMutation } = useSessionUserDataMutation();
  const router = useRouter();
  const { t } = useLanguage();

  const onValid: SubmitHandler<UserAboutSchema> = (data) => {
    updateSessionUserDataMutation.mutate(
      { data },
      {
        onError: (error) => {
          const { field, message } = JSON.parse(error.message) as {
            field: keyof UserAboutSchema;
            message: string;
          };
          setError(field, { message });
          setFocus(field);
        },
        onSuccess: () => router.push(redirectTo || profileHref(data.username)!),
      },
    );
  };

  const resetForm = useCallback(() => reset(defaultValues), [reset, defaultValues]);
  useEffect(() => reset(defaultValues), [reset, defaultValues]);

  if (!userData) return <GenericLoading>{t('正在加载资料…', 'Loading profile…')}</GenericLoading>;

  return (
    <form onSubmit={handleSubmit(onValid)} className="flex flex-col gap-4">
      <Controller
        control={control}
        name="username"
        render={({ field, fieldState: { error } }) => (
          <TextInput
            label={t('用户名', 'Username')}
            value={field.value}
            onChange={field.onChange}
            errorMessage={error?.message}
            ref={field.ref}
            Icon={AtSign}
          />
        )}
      />
      <Controller
        control={control}
        name="name"
        render={({ field, fieldState: { error } }) => (
          <TextInput
            label={t('昵称', 'Name')}
            value={field.value}
            onChange={field.onChange}
            errorMessage={error?.message}
            ref={field.ref}
            Icon={Profile}
          />
        )}
      />
      <Controller
        control={control}
        name="bio"
        render={({ field, fieldState: { error } }) => (
          <Textarea
            label={t('个人介绍', 'Bio')}
            value={field.value || ''}
            onChange={(value) => field.onChange(value || null)}
            errorMessage={error?.message}
            ref={field.ref}
            Icon={Bullhorn}
          />
        )}
      />
      <Controller
        control={control}
        name="website"
        render={({ field, fieldState: { error } }) => (
          <TextInput
            label={t('个人网站', 'Website')}
            value={field.value || ''}
            onChange={(value) => field.onChange(value || null)}
            errorMessage={error?.message}
            ref={field.ref}
            Icon={WorldNet}
          />
        )}
      />
      <div className="flex justify-end gap-4">
        <Button mode="secondary" type="button" loading={updateSessionUserDataMutation.isPending} onPress={resetForm}>
          {t('重置', 'Reset')}
        </Button>
        <Button type="submit" loading={updateSessionUserDataMutation.isPending}>
          {t('保存资料', 'Save profile')}
        </Button>
      </div>
    </form>
  );
}
