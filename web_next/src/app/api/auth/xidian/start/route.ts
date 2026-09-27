import { authorizeUrl, publicOrigin } from '@/lib/auth/xidianCas';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';

export async function GET(request: Request) {
  const attemptId = new URL(request.url).searchParams.get('attempt') || '';
  const attempt = await prisma.xidianLoginAttempt.findUnique({ where: { id: attemptId } });
  if (!attempt || attempt.status !== 'PENDING' || attempt.expiresAt <= new Date()) {
    return NextResponse.json({ message: '登录尝试已失效。' }, { status: 400 });
  }
  const origin = publicOrigin(request);
  return NextResponse.redirect(authorizeUrl(origin, attempt.id, attempt.state));
}
