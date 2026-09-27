import prisma from '@/lib/prisma/prisma';
import { getServerUser } from '@/lib/getServerUser';
import { includeToUser } from '@/lib/prisma/includeToUser';
import { toGetUser } from '@/lib/prisma/toGetUser';

export async function getProfile(username: string) {
  const [currentUser] = await getServerUser();
  const profile = await prisma.user.findFirst({
    where: {
      username,
    },
    include: includeToUser(currentUser?.id),
  });

  return profile ? toGetUser(profile) : null;
}
