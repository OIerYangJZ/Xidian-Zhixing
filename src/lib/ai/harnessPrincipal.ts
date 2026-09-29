import { createHmac } from 'crypto';

// Callers may supply scopes only after resolving the signed-in user's grants on the server.
export function createAgentPrincipalToken(userId: string, scopes: string[] = []) {
  const secret = process.env.AGENT_HARNESS_INTERNAL_SECRET;
  if (!secret) return undefined;
  const payload = Buffer.from(
    JSON.stringify({ sub: userId, scopes, iat: Math.floor(Date.now() / 1000) }),
  ).toString('base64url');
  const signature = createHmac('sha256', secret).update(payload).digest('base64url');
  return `${payload}.${signature}`;
}
