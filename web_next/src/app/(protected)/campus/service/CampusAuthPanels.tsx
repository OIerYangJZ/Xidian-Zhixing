'use client';

import { FormEvent, useState } from 'react';
import { useLanguage } from '@/hooks/useLanguage';

type Captcha = { imageBase64: string; imageContentType: string };

async function requestData(url: string, body?: Record<string, string>) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const result = await response.json();
  if (!response.ok) throw new Error(result.message || '请求失败。');
  return result.data;
}

function CampusFormMessage({ message, error }: { message: string; error: boolean }) {
  if (!message) return null;
  return (
    <p
      className={`mt-4 text-sm ${error ? 'text-destructive' : 'text-muted-foreground'}`}
      role={error ? 'alert' : 'status'}>
      {message}
    </p>
  );
}

function SchoolnetPanel({ authReady }: { authReady: boolean }) {
  const { t } = useLanguage();
  const [attemptId, setAttemptId] = useState('');
  const [captcha, setCaptcha] = useState<Captcha | null>(null);
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [isError, setIsError] = useState(false);
  const [result, setResult] = useState<{
    usage?: { summary?: Record<string, string>; onlineDevices?: Array<Record<string, string>> };
  } | null>(null);

  async function getCaptcha() {
    setBusy(true);
    setIsError(false);
    setMessage('');
    setResult(null);
    try {
      const data = await requestData('/api/campus/auth/schoolnet/captcha');
      setAttemptId(data.attemptId);
      setCaptcha(data);
    } catch (error) {
      setIsError(true);
      setMessage(error instanceof Error ? error.message : t('验证码获取失败。', 'Could not load the captcha.'));
    } finally {
      setBusy(false);
    }
  }

  async function login(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setIsError(false);
    setMessage('');
    try {
      const data = await requestData('/api/campus/auth/schoolnet/login', { attemptId, password, captcha: code });
      setResult(data);
      setPassword('');
      setMessage(
        t('校园网登录成功，以下是本次返回的状态。', 'Signed in to campus network service. Returned account status:'),
      );
    } catch (error) {
      setIsError(true);
      setMessage(error instanceof Error ? error.message : t('校园网登录失败。', 'Campus network sign-in failed.'));
    } finally {
      setBusy(false);
    }
  }

  if (!authReady)
    return (
      <CampusFormMessage
        message={t(
          '请先完成西电统一身份认证，再使用校园网自服务。',
          'Complete Xidian unified sign-in before using campus network self-service.',
        )}
        error
      />
    );
  return (
    <div className="mt-5 max-w-xl">
      <button
        type="button"
        onClick={getCaptcha}
        disabled={busy}
        className="rounded-full border border-border px-4 py-2 text-sm hover:bg-secondary disabled:opacity-60">
        {busy && !captcha
          ? t('正在获取验证码…', 'Loading captcha…')
          : t('获取校园网验证码', 'Get campus network captcha')}
      </button>
      {captcha ? (
        <form onSubmit={login} className="mt-4 space-y-3">
          <img
            src={`data:${captcha.imageContentType};base64,${captcha.imageBase64}`}
            alt={t('校园网图形验证码', 'Campus network captcha')}
            className="h-12 rounded border border-border"
          />
          <input
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder={t('校园网自服务密码', 'Campus network password')}
            className="w-full rounded-md border border-border bg-background px-3 py-2"
            required
          />
          <input
            value={code}
            onChange={(event) => setCode(event.target.value)}
            placeholder={t('图形验证码', 'Captcha')}
            className="w-full rounded-md border border-border bg-background px-3 py-2"
            required
          />
          <button
            type="submit"
            disabled={busy}
            className="rounded-full bg-primary px-4 py-2 text-sm font-medium text-primary-foreground disabled:opacity-60">
            {busy ? t('正在登录…', 'Signing in…') : t('登录并查询', 'Sign in and check usage')}
          </button>
        </form>
      ) : null}
      <CampusFormMessage message={message} error={isError} />
      {result?.usage ? (
        <div className="mt-5 space-y-3 text-sm">
          <div className="grid gap-2 sm:grid-cols-3">
            {Object.entries(result.usage.summary || {}).map(([name, value]) => (
              <p key={name} className="rounded-md bg-secondary p-3">
                <span className="block text-muted-foreground">
                  {{
                    used: t('已用流量', 'Used'),
                    rest: t('剩余流量', 'Remaining'),
                    charged: t('套餐余额', 'Plan balance'),
                  }[name] || name}
                </span>
                <strong className="mt-1 block">{value || '—'}</strong>
              </p>
            ))}
          </div>
          <div>
            <h3 className="font-medium">{t('在线设备', 'Online devices')}</h3>
            {result.usage.onlineDevices?.length ? (
              result.usage.onlineDevices.map((device) => (
                <p key={device.ip} className="mt-2 rounded-md border border-border p-3">
                  {device.ip} · {device.location} · {device.used}
                </p>
              ))
            ) : (
              <p className="mt-2 text-muted-foreground">
                {t('当前没有返回在线设备。', 'No online devices were returned.')}
              </p>
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function DormWaterPanel() {
  const { t } = useLanguage();
  const [captcha, setCaptcha] = useState<(Captcha & { sessionId: string }) | null>(null);
  const [phone, setPhone] = useState('');
  const [imageCode, setImageCode] = useState('');
  const [smsCode, setSmsCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [smsSent, setSmsSent] = useState(false);
  const [message, setMessage] = useState('');
  const [isError, setIsError] = useState(false);
  const [result, setResult] = useState<{ uid: string; eid: string; hasToken: boolean } | null>(null);

  async function getCaptcha() {
    setBusy(true);
    setIsError(false);
    setMessage('');
    setSmsSent(false);
    setResult(null);
    try {
      setCaptcha(await requestData('/api/campus/auth/dorm-water/captcha'));
    } catch (error) {
      setIsError(true);
      setMessage(error instanceof Error ? error.message : t('验证码获取失败。', 'Could not load the captcha.'));
    } finally {
      setBusy(false);
    }
  }

  async function sendSms(event: FormEvent) {
    event.preventDefault();
    if (!captcha) return;
    setBusy(true);
    setIsError(false);
    setMessage('');
    try {
      await requestData('/api/campus/auth/dorm-water/sms', { sessionId: captcha.sessionId, phone, imageCode });
      setSmsSent(true);
      setMessage(t('短信验证码已发送。', 'SMS verification code sent.'));
    } catch (error) {
      setIsError(true);
      setMessage(error instanceof Error ? error.message : t('短信发送失败。', 'Could not send the SMS code.'));
    } finally {
      setBusy(false);
    }
  }

  async function login(event: FormEvent) {
    event.preventDefault();
    if (!captcha) return;
    setBusy(true);
    setIsError(false);
    setMessage('');
    try {
      setResult(
        await requestData('/api/campus/auth/dorm-water/login', { sessionId: captcha.sessionId, phone, smsCode }),
      );
      setMessage(t('宿舍水机服务登录成功。', 'Signed in to the dorm water service.'));
    } catch (error) {
      setIsError(true);
      setMessage(error instanceof Error ? error.message : t('登录失败。', 'Sign-in failed.'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mt-5 max-w-xl">
      <button
        type="button"
        onClick={getCaptcha}
        disabled={busy}
        className="rounded-full border border-border px-4 py-2 text-sm hover:bg-secondary disabled:opacity-60">
        {busy && !captcha ? t('正在获取验证码…', 'Loading captcha…') : t('获取图形验证码', 'Get captcha')}
      </button>
      {captcha ? (
        <form onSubmit={sendSms} className="mt-4 space-y-3">
          <img
            src={`data:${captcha.imageContentType};base64,${captcha.imageBase64}`}
            alt={t('宿舍水机图形验证码', 'Dorm water service captcha')}
            className="h-12 rounded border border-border"
          />
          <input
            inputMode="tel"
            autoComplete="tel"
            value={phone}
            onChange={(event) => setPhone(event.target.value)}
            placeholder={t('手机号', 'Phone number')}
            className="w-full rounded-md border border-border bg-background px-3 py-2"
            required
          />
          <input
            value={imageCode}
            onChange={(event) => setImageCode(event.target.value)}
            placeholder={t('图形验证码', 'Captcha')}
            className="w-full rounded-md border border-border bg-background px-3 py-2"
            required
          />
          <button
            type="submit"
            disabled={busy}
            className="rounded-full border border-border px-4 py-2 text-sm disabled:opacity-60">
            {busy ? t('正在发送…', 'Sending…') : t('发送短信验证码', 'Send SMS code')}
          </button>
        </form>
      ) : null}
      {smsSent ? (
        <form onSubmit={login} className="mt-3 flex gap-2">
          <input
            value={smsCode}
            onChange={(event) => setSmsCode(event.target.value)}
            placeholder={t('短信验证码', 'SMS verification code')}
            className="min-w-0 flex-1 rounded-md border border-border bg-background px-3 py-2"
            required
          />
          <button
            type="submit"
            disabled={busy}
            className="rounded-full bg-primary px-4 py-2 text-sm font-medium text-primary-foreground disabled:opacity-60">
            {busy ? t('正在登录…', 'Signing in…') : t('登录', 'Sign in')}
          </button>
        </form>
      ) : null}
      <CampusFormMessage message={message} error={isError} />
      {result ? (
        <p className="mt-3 rounded-md bg-secondary p-3 text-sm">
          UID: {result.uid || '—'} · EID: {result.eid || '—'} · {t('登录凭证', 'Token')}:{' '}
          {result.hasToken ? t('已取得', 'received') : t('无', 'none')}
        </p>
      ) : null}
    </div>
  );
}

export function CampusAuthPanels({ serviceSlug, authReady }: { serviceSlug: string; authReady: boolean }) {
  return serviceSlug === 'dorm-water' ? <DormWaterPanel /> : <SchoolnetPanel authReady={authReady} />;
}
