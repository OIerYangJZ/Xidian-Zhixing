import 'server-only';
import { randomBytes, randomUUID } from 'crypto';
import prisma from '@/lib/prisma/prisma';

const ATTEMPT_TTL_MS = 10 * 60 * 1000;

export function publicOrigin(request: Request) {
  const configuredOrigin = process.env.XIDIAN_PUBLIC_ORIGIN?.trim();
  if (configuredOrigin) {
    const url = new URL(configuredOrigin);
    if (url.protocol !== 'https:' && process.env.NODE_ENV === 'production') {
      throw new Error('XIDIAN_PUBLIC_ORIGIN must use HTTPS in production');
    }
    return url.origin;
  }
  if (process.env.NODE_ENV === 'production') throw new Error('XIDIAN_PUBLIC_ORIGIN is required');
  return new URL(request.url).origin;
}

export function serviceUrl(origin: string, attemptId: string, state: string) {
  const service = new URL('/api/auth/xidian/callback', origin);
  service.searchParams.set('attempt', attemptId);
  service.searchParams.set('state', state);
  return service.toString();
}

export function authorizeUrl(origin: string, attemptId: string, state: string) {
  const login = new URL('https://ids.xidian.edu.cn/authserver/login');
  login.searchParams.set('service', serviceUrl(origin, attemptId, state));
  return login.toString();
}

export function safeCallbackUrl(value: unknown, origin: string) {
  if (typeof value !== 'string' || !value.trim()) return '/feed';
  const target = new URL(value, origin);
  return target.origin === origin ? `${target.pathname}${target.search}${target.hash}` : '/feed';
}

export function xidianCasIssuer() {
  return process.env.XIDIAN_CAS_ISSUER || 'https://ids.xidian.edu.cn/authserver';
}

export async function getXidianStudentId(userId: string) {
  const identity = await prisma.institutionIdentity.findFirst({
    where: { userId, issuer: xidianCasIssuer() },
    select: { subject: true },
  });
  return identity?.subject || null;
}

export async function createXidianLoginAttempt(request: Request, callbackUrl: unknown) {
  const origin = publicOrigin(request);
  const id = randomUUID();
  const state = randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + ATTEMPT_TTL_MS);
  await prisma.xidianLoginAttempt.create({
    data: { id, state, callbackUrl: safeCallbackUrl(callbackUrl, origin), expiresAt },
  });
  return { attemptId: id, authorizeUrl: authorizeUrl(origin, id, state), expiresAt };
}

function decodeXml(value: string) {
  return value
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

export function parseCasSuccess(xml: string) {
  const success = xml.match(
    /<(?:[\w.-]+:)?authenticationSuccess\b[^>]*>([\s\S]*?)<\/(?:[\w.-]+:)?authenticationSuccess\s*>/i,
  );
  if (!success) return null;
  const read = (names: string[]) => {
    for (const name of names) {
      const match = success[1].match(
        new RegExp(`<(?:[\\w.-]+:)?${name}\\b[^>]*>([\\s\\S]*?)<\\/(?:[\\w.-]+:)?${name}\\s*>`, 'i'),
      );
      if (match) return decodeXml(match[1].trim());
    }
    return '';
  };
  const studentId = read(['user', 'username', 'studentId']);
  if (!studentId) return null;
  return { studentId, email: read(['email', 'mail', 'emailAddress']) || null };
}
