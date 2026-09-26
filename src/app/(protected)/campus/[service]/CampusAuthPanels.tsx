'use client';

import { FormEvent, useState } from 'react';

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
      setMessage(error instanceof Error ? error.message : '验证码获取失败。');
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
      setMessage('校园网登录成功，以下是本次返回的状态。');
    } catch (error) {
      setIsError(true);
      setMessage(error instanceof Error ? error.message : '校园网登录失败。');
    } finally {
      setBusy(false);
    }
  }

  if (!authReady) return <CampusFormMessage message="请先完成西电统一身份认证，再使用校园网自服务。" error />;
  return (
    <div className="mt-5 max-w-xl">
      <button
        type="button"
        onClick={getCaptcha}
        disabled={busy}
        className="rounded-full border border-border px-4 py-2 text-sm hover:bg-secondary disabled:opacity-60">
        {busy && !captcha ? '正在获取验证码…' : '获取校园网验证码'}
      </button>
      {captcha ? (
        <form onSubmit={login} className="mt-4 space-y-3">
          <img
            src={`data:${captcha.imageContentType};base64,${captcha.imageBase64}`}
            alt="校园网图形验证码"
            className="h-12 rounded border border-border"
          />
          <input
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="校园网自服务密码"
            className="w-full rounded-md border border-border bg-background px-3 py-2"
            required
          />
          <input
            value={code}
            onChange={(event) => setCode(event.target.value)}
            placeholder="图形验证码"
            className="w-full rounded-md border border-border bg-background px-3 py-2"
            required
          />
          <button
            type="submit"
            disabled={busy}
            className="rounded-full bg-primary px-4 py-2 text-sm font-medium text-primary-foreground disabled:opacity-60">
            {busy ? '正在登录…' : '登录并查询'}
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
                  {{ used: '已用流量', rest: '剩余流量', charged: '套餐余额' }[name] || name}
                </span>
                <strong className="mt-1 block">{value || '—'}</strong>
              </p>
            ))}
          </div>
          <div>
            <h3 className="font-medium">在线设备</h3>
            {result.usage.onlineDevices?.length ? (
              result.usage.onlineDevices.map((device) => (
                <p key={device.ip} className="mt-2 rounded-md border border-border p-3">
                  {device.ip} · {device.location} · {device.used}
                </p>
              ))
            ) : (
              <p className="mt-2 text-muted-foreground">当前没有返回在线设备。</p>
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function DormWaterPanel() {
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
      setMessage(error instanceof Error ? error.message : '验证码获取失败。');
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
      setMessage('短信验证码已发送。');
    } catch (error) {
      setIsError(true);
      setMessage(error instanceof Error ? error.message : '短信发送失败。');
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
      setMessage('宿舍水机服务登录成功。');
    } catch (error) {
      setIsError(true);
      setMessage(error instanceof Error ? error.message : '登录失败。');
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
        {busy && !captcha ? '正在获取验证码…' : '获取图形验证码'}
      </button>
      {captcha ? (
        <form onSubmit={sendSms} className="mt-4 space-y-3">
          <img
            src={`data:${captcha.imageContentType};base64,${captcha.imageBase64}`}
            alt="宿舍水机图形验证码"
            className="h-12 rounded border border-border"
          />
          <input
            inputMode="tel"
            autoComplete="tel"
            value={phone}
            onChange={(event) => setPhone(event.target.value)}
            placeholder="手机号"
            className="w-full rounded-md border border-border bg-background px-3 py-2"
            required
          />
          <input
            value={imageCode}
            onChange={(event) => setImageCode(event.target.value)}
            placeholder="图形验证码"
            className="w-full rounded-md border border-border bg-background px-3 py-2"
            required
          />
          <button
            type="submit"
            disabled={busy}
            className="rounded-full border border-border px-4 py-2 text-sm disabled:opacity-60">
            {busy ? '正在发送…' : '发送短信验证码'}
          </button>
        </form>
      ) : null}
      {smsSent ? (
        <form onSubmit={login} className="mt-3 flex gap-2">
          <input
            value={smsCode}
            onChange={(event) => setSmsCode(event.target.value)}
            placeholder="短信验证码"
            className="min-w-0 flex-1 rounded-md border border-border bg-background px-3 py-2"
            required
          />
          <button
            type="submit"
            disabled={busy}
            className="rounded-full bg-primary px-4 py-2 text-sm font-medium text-primary-foreground disabled:opacity-60">
            {busy ? '正在登录…' : '登录'}
          </button>
        </form>
      ) : null}
      <CampusFormMessage message={message} error={isError} />
      {result ? (
        <p className="mt-3 rounded-md bg-secondary p-3 text-sm">
          UID：{result.uid || '—'} · EID：{result.eid || '—'} · 登录凭证：{result.hasToken ? '已取得' : '无'}
        </p>
      ) : null}
    </div>
  );
}

export function CampusAuthPanels({ serviceSlug, authReady }: { serviceSlug: string; authReady: boolean }) {
  return serviceSlug === 'dorm-water' ? <DormWaterPanel /> : <SchoolnetPanel authReady={authReady} />;
}
