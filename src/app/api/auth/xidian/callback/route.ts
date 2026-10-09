import { NextResponse } from 'next/server';
import { randomUUID } from 'crypto';
import prisma from '@/lib/prisma/prisma';
import { parseCasSuccess, publicOrigin, serviceUrl, xidianCasIssuer } from '@/lib/auth/xidianCas';
import { getAdminStudentNumbers } from '@/lib/auth/adminStudentNumbers';

function loginError(origin: string, code: string) {
  const target = new URL('/login', origin);
  target.searchParams.set('xidianError', code);
  return NextResponse.redirect(target);
}

export async function GET(request: Request) {
  let origin: string;
  try {
    origin = publicOrigin(request);
  } catch {
    return NextResponse.json({ message: '学校统一认证尚未配置。' }, { status: 503 });
  }
  if (new URL(request.url).origin !== origin) return loginError(origin, 'origin');

  const callback = new URL(request.url);
  const attemptId = callback.searchParams.get('attempt') || '';
  const state = callback.searchParams.get('state') || '';
  const ticket = callback.searchParams.get('ticket') || '';
  if (!attemptId || !state || !ticket) return loginError(origin, 'callback');

  const attempt = await prisma.xidianLoginAttempt.findFirst({
    where: { id: attemptId, state, status: 'PENDING', consumedAt: null, expiresAt: { gt: new Date() } },
  });
  if (!attempt) return loginError(origin, 'expired');

  const service = serviceUrl(origin, attempt.id, attempt.state);
  const validate = async (path: string) => {
    const url = new URL(path, 'https://ids.xidian.edu.cn');
    url.searchParams.set('service', service);
    url.searchParams.set('ticket', ticket);
    const response = await fetch(url, { cache: 'no-store', signal: AbortSignal.timeout(12_000) });
    if (!response.ok) throw new Error('CAS validation failed');
    return response.text();
  };

  let identity: ReturnType<typeof parseCasSuccess> = null;
  try {
    identity = parseCasSuccess(await validate('/authserver/p3/serviceValidate'));
    if (!identity) identity = parseCasSuccess(await validate('/authserver/serviceValidate'));
  } catch {
    await prisma.xidianLoginAttempt.updateMany({
      where: { id: attempt.id, status: 'PENDING' },
      data: { status: 'FAILED' },
    });
    return loginError(origin, 'validation');
  }
  if (!identity) {
    await prisma.xidianLoginAttempt.updateMany({
      where: { id: attempt.id, status: 'PENDING' },
      data: { status: 'FAILED' },
    });
    return loginError(origin, 'ticket');
  }
  if (!/^[A-Za-z0-9]{6,20}$/.test(identity.studentId)) {
    await prisma.xidianLoginAttempt.updateMany({
      where: { id: attempt.id, status: 'PENDING' },
      data: { status: 'FAILED' },
    });
    return loginError(origin, 'identity');
  }
  if (identity.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identity.email)) identity.email = null;
  const adminStudentNumbers = getAdminStudentNumbers();

  const approved = await prisma.$transaction(async (tx) => {
    const linked = await tx.institutionIdentity.findUnique({
      where: { issuer_subject: { issuer: xidianCasIssuer(), subject: identity!.studentId } },
      include: { user: { select: { id: true, status: true, role: true } } },
    });
    let user = linked?.user || null;
    if (!user && identity!.email) {
      user = await tx.user.findUnique({
        where: { email: identity!.email },
        select: { id: true, status: true, role: true },
      });
    }
    if (!user) {
      user = await tx.user.create({
        data: {
          username: `xidian_${randomUUID().replace(/-/g, '').slice(0, 16)}`,
          name: '西电同学',
          email: identity!.email,
        },
        select: { id: true, status: true, role: true },
      });
    }
    if (user.status !== 'ACTIVE') return false;

    if (!linked) {
      await tx.institutionIdentity.create({
        data: { issuer: xidianCasIssuer(), subject: identity!.studentId, userId: user.id },
      });
    }
    const shouldBeAdmin = adminStudentNumbers.has(identity!.studentId.toUpperCase());
    if ((shouldBeAdmin && user.role !== 'ADMIN') || (!shouldBeAdmin && user.role === 'ADMIN')) {
      await tx.user.update({ where: { id: user.id }, data: { role: shouldBeAdmin ? 'ADMIN' : 'USER' } });
    }
    const result = await tx.xidianLoginAttempt.updateMany({
      where: { id: attempt.id, state, status: 'PENDING', consumedAt: null, expiresAt: { gt: new Date() } },
      data: { status: 'APPROVED', userId: user.id },
    });
    return result.count === 1;
  });
  if (!approved) return loginError(origin, 'account');

  const target = new URL(attempt.callbackUrl === '/miniprogram-auth' ? '/miniprogram-auth' : '/login', origin);
  target.searchParams.set('attempt', attempt.id);
  return NextResponse.redirect(target);
}
