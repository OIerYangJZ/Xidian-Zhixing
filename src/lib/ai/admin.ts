import 'server-only';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';

export async function getKnowledgeAdmin() {
  const [sessionUser] = await getServerUser();
  if (!sessionUser?.id) return null;
  const user = await prisma.user.findUnique({
    where: { id: sessionUser.id },
    select: { id: true, role: true, status: true },
  });
  return user?.role === 'ADMIN' && user.status === 'ACTIVE' ? user : null;
}
