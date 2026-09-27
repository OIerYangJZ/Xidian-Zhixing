import { z } from 'zod';

/** Mirrors PATCH /api/users/me: nickname, bio ≤100, gender ""|男|女, college/major ≤80. */
export const userAboutSchema = z.object({
  nickname: z.string().trim().min(1, { message: '请填写昵称' }).max(24, { message: '昵称最多 24 个字' }),
  bio: z.string().trim().max(100, { message: '个人介绍最多 100 个字' }),
  gender: z.enum(['', '男', '女']),
  college: z.string().trim().max(80, { message: '最多 80 个字' }),
  major: z.string().trim().max(80, { message: '最多 80 个字' }),
});

export type UserAboutSchema = z.infer<typeof userAboutSchema>;
