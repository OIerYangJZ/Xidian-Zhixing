import 'server-only';
import { cache } from 'react';
import { auth } from '@/auth';
import prisma from '@/lib/prisma/prisma';
import { headers } from 'next/headers';
import { getMiniProgramTokenUserId } from '@/lib/auth/miniProgramToken';

export const getServerUser = cache(async function getServerUser() {
  const session = await auth();
  let user = session?.user;
  if (!user?.id) {
    const authorization = (await headers()).get('authorization') || '';
    const match = /^Bearer\s+(.+)$/i.exec(authorization);
    const userId = match ? getMiniProgramTokenUserId(match[1]) : null;
    if (userId) {
      const miniProgramUser = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, name: true, email: true, role: true },
      });
      if (miniProgramUser) {
        user = { ...miniProgramUser, name: miniProgramUser.name || '' };
      }
    }
  }
  if (!user?.id) return [null];
  const account = await prisma.user.findUnique({ where: { id: user.id }, select: { status: true } });
  return [account?.status === 'ACTIVE' ? user : null];
});
