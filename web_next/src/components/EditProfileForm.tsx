'use client';

import { Controller, SubmitHandler, useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { Bullhorn, Profile } from '@/svg_components';
import { UserAboutSchema, userAboutSchema } from '@/lib/validations/userAbout';
import { useMe } from '@/lib/backend/session';
import { useErrorNotifier } from '@/hooks/useErrorNotifier';
import { useSessionUserDataMutation } from '@/hooks/mutations/useSessionUserDataMutation';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo } from 'react';
import { useLanguage } from '@/hooks/useLanguage';
import { profileHref } from '@/lib/profileHref';
import { GenericLoading } from './GenericLoading';
import { Textarea } from './ui/Textarea';
import Button from './ui/Button';
import { TextInput } from './ui/TextInput';

export function EditProfileForm({ redirectTo }: { redirectTo?: string }) {
  const { me } = useMe();
  const defaultValues = useMemo<UserAboutSchema>(
    () => ({
      nickname: me?.nickname || '',
      bio: me?.bio || '',
      gender: me?.gender === '男' || me?.gender === '女' ? me.gender : '',
      college: me?.college || '',
      major: me?.major || '',
    }),
    [me],
  );
  const { control, handleSubmit, reset } = useForm<UserAboutSchema>({
    resolver: zodResolver(userAboutSchema),
    defaultValues,
  });
  const { updateSessionUserDataMutation } = useSessionUserDataMutation();
  const { notifyError } = useErrorNotifier();
  const router = useRouter();
  const { t } = useLanguage();

  const onValid: SubmitHandler<UserAboutSchema> = (data) => {
    updateSessionUserDataMutation.mutate(
      { data },
      {
        onError: (error) => notifyError(error, t('保存失败', 'Could not save')),
        onSuccess: () => router.push(redirectTo || profileHref(me?.id) || '/feed'),
      },
    );
  };

  const resetForm = useCallback(() => reset(defaultValues), [reset, defaultValues]);
  useEffect(() => reset(defaultValues), [reset, defaultValues]);

  if (!me) return <GenericLoading>{t('正在加载资料…', 'Loading profile…')}</GenericLoading>;

  const textField = (name: 'nickname' | 'college' | 'major', label: string, Icon?: typeof Profile) => (
    <Controller
      control={control}
      name={name}
      render={({ field, fieldState: { error } }) => (
        <TextInput
          label={label}
          value={field.value}
          onChange={field.onChange}
          errorMessage={error?.message}
          ref={field.ref}
          Icon={Icon}
        />
      )}
    />
  );

  return (
    <form onSubmit={handleSubmit(onValid)} className="flex flex-col gap-4">
      {textField('nickname', t('昵称', 'Name'), Profile)}
      <Controller
        control={control}
        name="bio"
        render={({ field, fieldState: { error } }) => (
          <Textarea
            label={t('个人介绍', 'Bio')}
            value={field.value}
            onChange={field.onChange}
            errorMessage={error?.message}
            ref={field.ref}
            Icon={Bullhorn}
          />
        )}
      />
      <Controller
        control={control}
        name="gender"
        render={({ field }) => (
          <label className="flex items-center justify-between gap-3 text-sm">
            <span>{t('性别', 'Gender')}</span>
            <select
              value={field.value}
              onChange={(event) => field.onChange(event.target.value)}
              className="min-h-10 border border-border bg-background px-3 text-foreground">
              <option value="">{t('不展示', 'Not shown')}</option>
              <option value="男">{t('男', 'Male')}</option>
              <option value="女">{t('女', 'Female')}</option>
            </select>
          </label>
        )}
      />
      {textField('college', t('学院', 'College'))}
      {textField('major', t('专业', 'Major'))}
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
