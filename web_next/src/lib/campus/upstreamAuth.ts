import 'server-only';
import { constants, publicEncrypt, randomInt, randomUUID } from 'crypto';
import { CampusAuthError } from './CampusAuthError';

export { CampusAuthError } from './CampusAuthError';

const SCHOOLNET = 'https://zfw.xidian.edu.cn';
const DORM_WATER = 'https://i.ilife798.com';
const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
const TEXT_LIMIT = 2 * 1024 * 1024;
const IMAGE_LIMIT = 5 * 1024 * 1024;

type CookieAttempt = {
  ownerUserId: string;
  expiresAt: number;
  session: CookieSession;
  csrfName: string;
  csrfValue: string;
  publicKey: string;
};
type WaterAttempt = { ownerUserId: string; expiresAt: number; phone?: string };
const schoolnetAttempts = new Map<string, CookieAttempt>();
const waterAttempts = new Map<string, WaterAttempt>();

class CookieSession {
  private readonly cookies = new Map<string, string>();

  async fetch(url: string, init: RequestInit = {}) {
    let nextUrl = url;
    let method = init.method || 'GET';
    let { body } = init;
    for (let redirects = 0; redirects <= 5; redirects += 1) {
      const headers = new Headers(init.headers);
      headers.set('User-Agent', USER_AGENT);
      headers.set('Host', new URL(nextUrl).host);
      if (this.cookies.size)
        headers.set('Cookie', [...this.cookies].map(([name, value]) => `${name}=${value}`).join('; '));
      // Each redirect depends on the prior response's location and cookies.
      // eslint-disable-next-line no-await-in-loop
      const response = await fetch(nextUrl, {
        ...init,
        method,
        body,
        headers,
        redirect: 'manual',
        signal: AbortSignal.timeout(20_000),
      });
      const responseHeaders = response.headers as Headers & { getSetCookie?: () => string[] };
      const setCookies =
        responseHeaders.getSetCookie?.() ||
        (response.headers.get('set-cookie') ? [response.headers.get('set-cookie')!] : []);
      for (const item of setCookies) {
        const pair = item.split(';', 1)[0];
        const separator = pair.indexOf('=');
        if (separator < 1) continue;
        const name = pair.slice(0, separator).trim();
        const value = pair.slice(separator + 1).trim();
        if (/max-age=0/i.test(item) || /expires=Thu, 01 Jan 1970/i.test(item)) this.cookies.delete(name);
        else this.cookies.set(name, value);
      }
      const location = response.headers.get('location');
      if (![301, 302, 303, 307, 308].includes(response.status) || !location) return response;
      const redirectUrl = new URL(location, nextUrl);
      if (redirectUrl.origin !== new URL(nextUrl).origin) throw new CampusAuthError(503, '校园网认证跳转地址异常。');
      nextUrl = redirectUrl.toString();
      if ([301, 302, 303].includes(response.status) && method !== 'GET' && method !== 'HEAD') {
        method = 'GET';
        body = undefined;
      }
    }
    throw new CampusAuthError(503, '校园服务跳转次数超出限制。');
  }
}

function responseCookiesExpired(expiresAt: number) {
  return expiresAt <= Date.now();
}

function htmlInputs(html: string) {
  return [...html.matchAll(/<input\b[^>]*>/gi)].map(([tag]) => {
    const attrs: Record<string, string> = {};
    for (const [, name, , value] of tag.matchAll(/([\w:-]+)\s*=\s*(["'])(.*?)\2/gi)) {
      attrs[name.toLowerCase()] = value;
    }
    return attrs;
  });
}

function xmlSafeText(text: string) {
  return text
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;|&#160;/gi, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

function imageType(bytes: Uint8Array) {
  if (bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (bytes.length > 8 && bytes.slice(0, 8).join(',') === '137,80,78,71,13,10,26,10') return 'image/png';
  if (bytes.length > 6 && String.fromCharCode(...bytes.slice(0, 6)).startsWith('GIF8')) return 'image/gif';
  if (
    bytes.length > 12 &&
    String.fromCharCode(...bytes.slice(0, 4)) === 'RIFF' &&
    String.fromCharCode(...bytes.slice(8, 12)) === 'WEBP'
  )
    return 'image/webp';
  return '';
}

async function readText(response: Response) {
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.length > TEXT_LIMIT) throw new CampusAuthError(503, '校园服务响应内容过大。');
  return new TextDecoder('utf-8').decode(bytes);
}

async function readImage(response: Response) {
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.length > IMAGE_LIMIT) throw new CampusAuthError(503, '验证码图片超过大小限制。');
  const detectedType = imageType(bytes);
  if (!detectedType) throw new CampusAuthError(503, '验证码服务返回的内容不是图片。');
  return { imageBase64: Buffer.from(bytes).toString('base64'), imageContentType: detectedType };
}

function cleanAttempts() {
  for (const [id, attempt] of schoolnetAttempts)
    if (responseCookiesExpired(attempt.expiresAt)) schoolnetAttempts.delete(id);
  for (const [id, attempt] of waterAttempts) if (responseCookiesExpired(attempt.expiresAt)) waterAttempts.delete(id);
}

export async function createSchoolnetCaptcha(userId: string, studentId: string) {
  cleanAttempts();
  const session = new CookieSession();
  const loginResponse = await session.fetch(`${SCHOOLNET}/login`);
  if (!loginResponse.ok) throw new CampusAuthError(503, '无法连接校园网自服务。');
  const inputs = htmlInputs(await readText(loginResponse));
  const csrf = inputs.find((input) => (input.name || '').toLowerCase().includes('csrf') && input.value);
  const publicKey = inputs.find((input) => (input.id || '').toLowerCase().includes('public') && input.value)?.value;
  if (!csrf?.name || !csrf.value || !publicKey) throw new CampusAuthError(503, '校园网登录页字段已变化。');

  await session.fetch(`${SCHOOLNET}/site/captcha?refresh=1&_=${Date.now()}`);
  const captchaResponse = await session.fetch(`${SCHOOLNET}/site/captcha`);
  if (!captchaResponse.ok) throw new CampusAuthError(503, '校园网验证码获取失败。');
  const image = await readImage(captchaResponse);
  const attemptId = randomUUID();
  const expiresAt = Date.now() + 8 * 60 * 1000;
  schoolnetAttempts.set(attemptId, {
    ownerUserId: userId,
    expiresAt,
    session,
    csrfName: csrf.name,
    csrfValue: csrf.value,
    publicKey,
  });
  return { attemptId, ...image, expiresInSeconds: 480, studentId };
}

function loadSchoolnetAttempt(attemptId: string, userId: string) {
  cleanAttempts();
  const attempt = schoolnetAttempts.get(attemptId);
  if (!attempt || attempt.ownerUserId !== userId) throw new CampusAuthError(410, '校园网验证码已过期，请重新获取。');
  return attempt;
}

function parseSchoolnetUsage(html: string) {
  const rows = [...html.matchAll(/<tr[^>]*>([\s\S]*?)<\/tr>/gi)].map((row) => row[1]);
  const onlineDevices: Array<{ ip: string; location: string; used: string }> = [];
  let summary = { used: '', rest: '', charged: '' };
  for (const row of rows) {
    const cells = [...row.matchAll(/<td[^>]*>([\s\S]*?)<\/td>/gi)].map((cell) => xmlSafeText(cell[1]));
    if (cells.length === 7 && cells[2]) onlineDevices.push({ ip: cells[1], location: cells[3], used: cells[2] });
    if (cells.length === 4 && !['联通', '移动', '电信'].some((carrier) => cells[0].includes(carrier))) {
      summary = { used: cells[1], rest: cells[2], charged: cells[3] };
    }
  }
  return { summary, onlineDevices };
}

export async function loginSchoolnet(input: {
  userId: string;
  attemptId: string;
  studentId: string;
  password: string;
  captcha: string;
}) {
  const { userId, attemptId, studentId, password, captcha } = input;
  const attempt = loadSchoolnetAttempt(attemptId, userId);
  if (!/^[A-Za-z0-9]{6,20}$/.test(studentId) || !password || !captcha.trim())
    throw new CampusAuthError(400, '请填写有效的校园网密码和验证码。');
  let publicKey = attempt.publicKey.trim();
  if (!publicKey.includes('BEGIN PUBLIC KEY')) {
    const compact = publicKey.replace(/\s+/g, '');
    publicKey = `-----BEGIN PUBLIC KEY-----\n${compact.match(/.{1,64}/g)?.join('\n')}\n-----END PUBLIC KEY-----`;
  }
  const encryptedPassword = publicEncrypt(
    { key: publicKey, padding: constants.RSA_PKCS1_PADDING },
    Buffer.from(password, 'utf8'),
  ).toString('base64');
  const headers = {
    'X-CSRF-Token': attempt.csrfValue,
    Accept: '*/*',
    'X-Requested-With': 'XMLHttpRequest',
    'Content-Type': 'application/x-www-form-urlencoded',
  };
  const validatePayload = new URLSearchParams({
    'LoginForm[username]': studentId,
    'LoginForm[password]': encryptedPassword,
    'LoginForm[verifyCode]': captcha.trim(),
  });
  const validationResponse = await attempt.session.fetch(`${SCHOOLNET}/site/validate-user`, {
    method: 'POST',
    headers,
    body: validatePayload,
  });
  if (!validationResponse.ok) throw new CampusAuthError(503, '校园网登录预校验失败。');
  let validation: { success?: boolean; message?: string };
  try {
    validation = JSON.parse(await readText(validationResponse));
  } catch {
    throw new CampusAuthError(503, '校园网登录预校验响应异常。');
  }
  if (!validation.success) throw new CampusAuthError(401, validation.message || '校园网账号、密码或验证码错误。');

  const loginPayload = new URLSearchParams({
    [attempt.csrfName]: attempt.csrfValue,
    'LoginForm[username]': studentId,
    'LoginForm[password]': encryptedPassword,
    'LoginForm[smsCode]': '',
    'LoginForm[verifyCode]': captcha.trim(),
  });
  const loginResponse = await attempt.session.fetch(`${SCHOOLNET}/`, { method: 'POST', headers, body: loginPayload });
  if (!loginResponse.ok) throw new CampusAuthError(503, '校园网登录失败。');
  const home = await attempt.session.fetch(`${SCHOOLNET}/home`);
  if (!home.ok || new URL(home.url).origin !== SCHOOLNET) throw new CampusAuthError(503, '校园网登录后查询失败。');
  const homeHtml = await readText(home);
  if (/\/login/i.test(home.url) || /<input[^>]+name=["']LoginForm\[username\]["']/i.test(homeHtml))
    throw new CampusAuthError(401, '校园网账号、密码或验证码错误。');
  const usage = parseSchoolnetUsage(homeHtml);
  if (
    !usage.onlineDevices.length &&
    !Object.values(usage.summary).some(Boolean) &&
    !/(?:退出登录|注销登录|在线设备|已用流量|剩余流量|套餐余额)/i.test(homeHtml)
  ) {
    throw new CampusAuthError(503, '校园网未返回可确认的登录状态。');
  }
  schoolnetAttempts.delete(attemptId);
  return { status: 'authenticated', usage };
}

export async function createDormWaterCaptcha(userId: string) {
  cleanAttempts();
  const sessionId = Array.from({ length: 16 }, () => String(randomInt(0, 10))).join('');
  const url = new URL('/api/v1/captcha/', DORM_WATER);
  url.searchParams.set('s', sessionId);
  url.searchParams.set('r', String(Date.now()));
  const response = await fetch(url, {
    headers: {
      accept: '*/*',
      'User-Agent': 'iLife798/3.1.1 (iPhone; iOS 26.2; Scale/3.00)',
      'accept-language': 'zh-Hans-US;q=1, en-US;q=0.8',
    },
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new CampusAuthError(503, '宿舍水机验证码获取失败。');
  const image = await readImage(response);
  waterAttempts.set(sessionId, { ownerUserId: userId, expiresAt: Date.now() + 5 * 60 * 1000 });
  return { sessionId, ...image, expiresInSeconds: 300 };
}

function loadWaterAttempt(sessionId: string, userId: string) {
  cleanAttempts();
  const attempt = waterAttempts.get(sessionId);
  if (!attempt || attempt.ownerUserId !== userId) throw new CampusAuthError(410, '宿舍水机验证码已过期，请重新获取。');
  return attempt;
}

function validPhone(value: string) {
  const phone = value.replace(/\s+/g, '');
  if (!/^1\d{10}$/.test(phone)) throw new CampusAuthError(400, '请输入有效手机号。');
  return phone;
}

async function waterPost(path: string, body: Record<string, string>) {
  const response = await fetch(new URL(path, DORM_WATER), {
    method: 'POST',
    headers: { accept: '*/*', 'content-type': 'application/json', 'User-Agent': 'iOS_ilife798_3.1.1' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new CampusAuthError(503, '宿舍水机服务暂时不可用。');
  try {
    return (await response.json()) as { code?: number; data?: Record<string, unknown> };
  } catch {
    throw new CampusAuthError(503, '宿舍水机服务响应异常。');
  }
}

export async function sendDormWaterSms(input: { userId: string; sessionId: string; phone: string; imageCode: string }) {
  const attempt = loadWaterAttempt(input.sessionId, input.userId);
  const phone = validPhone(input.phone);
  if (!input.imageCode.trim()) throw new CampusAuthError(400, '请输入图形验证码。');
  if (attempt.phone && attempt.phone !== phone) throw new CampusAuthError(400, '验证码会话与手机号不匹配。');
  const result = await waterPost('/api/v1/acc/login/code', {
    s: input.sessionId,
    authCode: input.imageCode.trim(),
    un: phone,
  });
  if (result.code !== 0) throw new CampusAuthError(400, '短信发送失败，请检查图形验证码。');
  attempt.phone = phone;
  return { status: 'sms_sent' };
}

export async function loginDormWater(input: { userId: string; sessionId: string; phone: string; smsCode: string }) {
  const attempt = loadWaterAttempt(input.sessionId, input.userId);
  const phone = validPhone(input.phone);
  if (!attempt.phone || attempt.phone !== phone) throw new CampusAuthError(400, '请先为当前手机号发送短信验证码。');
  if (!input.smsCode.trim()) throw new CampusAuthError(400, '请输入短信验证码。');
  const result = await waterPost('/api/v1/acc/login', { cid: '', authCode: input.smsCode.trim(), un: phone });
  if (result.code !== 0) throw new CampusAuthError(401, '宿舍水机登录失败，请检查短信验证码。');
  const account = result.data?.al as Record<string, unknown> | undefined;
  if (!account || typeof account.token !== 'string' || !account.token)
    throw new CampusAuthError(401, '宿舍水机未返回有效登录凭证。');
  waterAttempts.delete(input.sessionId);
  return { status: 'authenticated', uid: String(account.uid || ''), eid: String(account.eid || ''), hasToken: true };
}
