import 'server-only';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { getAdminStudentNumbers } from '@/lib/auth/adminStudentNumbers';
import { xidianCasIssuer } from '@/lib/auth/xidianCas';

export async function getKnowledgeAdmin() {
  const [sessionUser] = await getServerUser();
  if (!sessionUser?.id) return null;
  const user = await prisma.user.findUnique({
    where: { id: sessionUser.id },
    select: {
      id: true,
      role: true,
      status: true,
      institutionIdentities: { where: { issuer: xidianCasIssuer() }, select: { subject: true } },
    },
  });
  if (!user || user.role !== 'ADMIN' || user.status !== 'ACTIVE') return null;

  const isLocalAdmin =
    process.env.NODE_ENV !== 'production' && process.env.LOCAL_TEST_AUTH === 'true' && user.id === 'local-test-student';
  const adminStudentNumbers = getAdminStudentNumbers();
  const isConfiguredAdmin = user.institutionIdentities.some((identity) =>
    adminStudentNumbers.has(identity.subject.toUpperCase()),
  );
  return isLocalAdmin || isConfiguredAdmin ? user : null;
}
