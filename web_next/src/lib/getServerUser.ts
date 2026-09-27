import 'server-only';
import { auth } from '@/auth';
import prisma from '@/lib/prisma/prisma';

export async function getServerUser() {
  const session = await auth();
  const user = session?.user;
  if (!user?.id) return [null];
  const account = await prisma.user.findUnique({ where: { id: user.id }, select: { status: true } });
  return [account?.status === 'ACTIVE' ? user : null];
}
