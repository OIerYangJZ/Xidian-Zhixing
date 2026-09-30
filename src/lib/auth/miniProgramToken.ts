import { createHmac, timingSafeEqual } from 'node:crypto';

const TOKEN_TTL_SECONDS = 7 * 24 * 60 * 60;
const TOKEN_ISSUER = 'zhixing';
const TOKEN_AUDIENCE = 'wechat-miniprogram';

function secret() {
  const value = process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET;
  if (!value) throw new Error('AUTH_SECRET is required for mini-program sessions');
  return value;
}

function encode(value: unknown) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function sign(content: string) {
  return createHmac('sha256', secret()).update(content).digest();
}

export function createMiniProgramToken(userId: string) {
  const now = Math.floor(Date.now() / 1000);
  const expiresAt = now + TOKEN_TTL_SECONDS;
  const content = [
    encode({ alg: 'HS256', typ: 'JWT' }),
    encode({ iss: TOKEN_ISSUER, aud: TOKEN_AUDIENCE, sub: userId, iat: now, exp: expiresAt }),
  ].join('.');

  return {
    token: `${content}.${sign(content).toString('base64url')}`,
    expiresAt: new Date(expiresAt * 1000).toISOString(),
  };
}

export function getMiniProgramTokenUserId(value: string) {
  const [headerPart, payloadPart, signaturePart, extraPart] = value.split('.');
  if (!headerPart || !payloadPart || !signaturePart || extraPart) return null;

  try {
    const content = `${headerPart}.${payloadPart}`;
    const signature = Buffer.from(signaturePart, 'base64url');
    const expected = sign(content);
    if (signature.length !== expected.length || !timingSafeEqual(signature, expected)) return null;

    const header = JSON.parse(Buffer.from(headerPart, 'base64url').toString('utf8')) as { alg?: string };
    const payload = JSON.parse(Buffer.from(payloadPart, 'base64url').toString('utf8')) as {
      iss?: string;
      aud?: string;
      sub?: string;
      exp?: number;
    };
    if (
      header.alg !== 'HS256' ||
      payload.iss !== TOKEN_ISSUER ||
      payload.aud !== TOKEN_AUDIENCE ||
      typeof payload.sub !== 'string' ||
      !payload.sub ||
      typeof payload.exp !== 'number' ||
      payload.exp <= Math.floor(Date.now() / 1000)
    ) return null;

    return payload.sub;
  } catch {
    return null;
  }
}
