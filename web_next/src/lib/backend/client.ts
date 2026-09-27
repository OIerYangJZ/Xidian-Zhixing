/**
 * The one way this frontend talks to the Python backend.
 *
 * Every response is `{"data": ...}` on success and `{"message": ..., "data"?}`
 * on failure; `api()` unwraps the former and throws `ApiError` for the
 * latter.  Authentication is the bearer token from ./token — the backend
 * never reads cookies for API calls.
 */
import { clearToken, getToken } from './token';

export class ApiError extends Error {
  readonly status: number;

  readonly data: unknown;

  constructor(status: number, message: string, data?: unknown) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.data = data;
  }

  /** The backend marks banned sessions with data.accountState = 'banned'. */
  get isBanned(): boolean {
    return (this.data as { accountState?: string } | undefined)?.accountState === 'banned';
  }
}

type Query = Record<string, string | number | boolean | null | undefined>;

export interface ApiOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE';
  query?: Query;
  body?: unknown;
  signal?: AbortSignal;
}

let onUnauthorized: (() => void) | null = null;

/** Registered by the session provider so a dead token signs the user out. */
export function setUnauthorizedHandler(handler: (() => void) | null) {
  onUnauthorized = handler;
}

export function buildUrl(path: string, query?: Query): string {
  if (!query) return path;
  const params = new URLSearchParams();
  Object.entries(query).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') return;
    params.set(key, String(value));
  });
  const qs = params.toString();
  return qs ? `${path}?${qs}` : path;
}

async function readJson(response: Response): Promise<Record<string, unknown> | null> {
  if (response.status === 204) return null;
  const text = await response.text();
  if (!text) return null;
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    return null;
  }
}

/** Fetch `path` and return the unwrapped `data` field. */
export async function api<T>(path: string, options: ApiOptions = {}): Promise<T> {
  const { method = 'GET', query, body, signal } = options;
  const headers: Record<string, string> = { Accept: 'application/json' };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';

  const response = await fetch(buildUrl(path, query), {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    signal,
    cache: 'no-store',
  });
  const payload = await readJson(response);

  if (!response.ok) {
    const message = typeof payload?.message === 'string' ? payload.message : `请求失败（${response.status}）`;
    if (response.status === 401 && token) {
      clearToken();
      onUnauthorized?.();
    }
    throw new ApiError(response.status, message, payload?.data);
  }
  return (payload?.data ?? payload) as T;
}
