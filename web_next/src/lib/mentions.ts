import type { Mention } from '@/types/definitions';

/**
 * Nicknames picked from the @-mention list during this visit, mapped to the
 * account they belong to.  Kept per page rather than per text box because
 * replies are typed into a shared prompt dialog that only hands back text.
 */
const picked = new Map<string, string>();

export function rememberMention(nickname: string, userId: string) {
  if (nickname && userId) picked.set(nickname, userId);
}

/**
 * Accounts to send as mentionUserIds: every remembered (or already stored)
 * nickname whose "@nickname" is still in the text.  The backend checks the
 * same thing, so a deleted mention is simply not sent.
 */
export function mentionIdsIn(text: string, known: Mention[] = []): string[] {
  const ids = new Set<string>();
  known.forEach(({ nickname, userId }) => {
    if (text.includes(`@${nickname}`)) ids.add(userId);
  });
  picked.forEach((userId, nickname) => {
    if (text.includes(`@${nickname}`)) ids.add(userId);
  });
  return [...ids];
}
