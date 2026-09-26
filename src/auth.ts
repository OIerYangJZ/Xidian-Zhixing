import NextAuth from 'next-auth';
import Credentials from 'next-auth/providers/credentials';
import { PrismaAdapter } from '@auth/prisma-adapter';
import authConfig from '@/auth.config';
import prisma from '@/lib/prisma/prisma';
import { seedLocalTestData } from '@/lib/dev/seedLocalTestData';

const localTestProvider = Credentials({
  id: 'local-test',
  name: '本地测试账户',
  credentials: {},
  async authorize() {
    if (process.env.NODE_ENV === 'production' || process.env.LOCAL_TEST_AUTH !== 'true') return null;

    const databaseUrl = new URL(process.env.DATABASE_URL!);
    if (!['localhost', '127.0.0.1', '[::1]', '::1'].includes(databaseUrl.hostname)) return null;

    const user = await prisma.user.upsert({
      where: { id: 'local-test-student' },
      update: { status: 'ACTIVE', role: 'ADMIN' },
      create: {
        id: 'local-test-student',
        username: 'localtest',
        name: '本地测试同学',
        role: 'ADMIN',
      },
      select: { id: true, name: true, email: true },
    });

    await seedLocalTestData(user.id);
    return user;
  },
});

const xidianAttemptProvider = Credentials({
  id: 'xidian-attempt',
  name: '西电 IDS',
  credentials: { attemptId: { label: 'Login attempt', type: 'text' } },
  async authorize(credentials) {
    const attemptId = typeof credentials?.attemptId === 'string' ? credentials.attemptId : '';
    if (!attemptId) return null;
    const now = new Date();
    const claimed = await prisma.xidianLoginAttempt.updateMany({
      where: { id: attemptId, status: 'APPROVED', consumedAt: null, expiresAt: { gt: now } },
      data: { consumedAt: now },
    });
    if (claimed.count !== 1) return null;
    const attempt = await prisma.xidianLoginAttempt.findUnique({
      where: { id: attemptId },
      select: { user: { select: { id: true, name: true, email: true } } },
    });
    return attempt?.user || null;
  },
});

declare module 'next-auth' {
  interface Session {
    user: { id: string; name: string; role?: string };
  }
}

export const {
  auth,
  handlers: { GET, POST },
  signIn,
} = NextAuth({
  ...authConfig,
  providers: [...authConfig.providers, xidianAttemptProvider, localTestProvider],
  adapter: PrismaAdapter(prisma),
  session: {
    strategy: 'jwt',
  },
  callbacks: {
    ...authConfig.callbacks,
    async jwt({ token, user }) {
      if (user?.id) {
        const account = await prisma.user.findUnique({ where: { id: user.id }, select: { role: true } });
        return { ...token, role: account?.role };
      }
      return token;
    },
    async signIn({ user }) {
      if (!user.id) return false;

      const account = await prisma.user.findUnique({
        where: { id: user.id },
        select: { status: true },
      });

      return account?.status === 'ACTIVE';
    },
    session({ token, session }) {
      return {
        ...session,
        user: {
          ...session.user,
          id: token.sub!,
          role: (token as typeof token & { role?: string }).role,
        },
      };
    },
  },
});
