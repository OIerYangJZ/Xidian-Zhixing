import { z } from 'zod';

const nonEmptyString = z.string().trim().min(3, { message: 'At least three characters are required' });

export const userAboutSchema = z.object({
  username: nonEmptyString.regex(/^[a-zA-Z0-9_]+$/, {
    message: 'Use only letters, numbers, and underscores',
  }),
  name: nonEmptyString,
  bio: nonEmptyString.nullable(),
  website: nonEmptyString
    .regex(/^(?:https?:\/\/)?(?:www\.)?([a-zA-Z0-9-]+\.[a-zA-Z]{2,})(?:\/[^\s]*)?$/, {
      message: 'Enter a valid website URL',
    })
    .nullable(),
});

export type UserAboutSchema = z.infer<typeof userAboutSchema>;
