/**
 * Bearer token storage.  localStorage survives reloads and is shared across
 * tabs; the HttpOnly `zx_session` cookie the backend sets alongside it only
 * lets Nginx decide whether a signed-in page may load (see ./session).
 */
const TOKEN_KEY = 'zx_token';

export function getToken(): string {
  if (typeof window === 'undefined') return '';
  try {
    return window.localStorage.getItem(TOKEN_KEY) || '';
  } catch {
    return '';
  }
}

export function setToken(token: string) {
  try {
    window.localStorage.setItem(TOKEN_KEY, token);
  } catch {
    // Private mode without storage: the session lasts until the tab closes.
  }
}

export function clearToken() {
  try {
    window.localStorage.removeItem(TOKEN_KEY);
  } catch {
    // Nothing stored, nothing to clear.
  }
}
