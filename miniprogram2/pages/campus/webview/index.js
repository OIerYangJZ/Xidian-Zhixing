import { baseUrl } from '../../../config/env';

// Only these hosts may be rendered inside <web-view>.  The page is reachable
// with an attacker-influenced `url` query (announcements/banners carry server
// data), and a web-view is a full browser: an arbitrary origin there can phish
// for campus credentials under our own UI chrome.
const ALLOWED_HOST_SUFFIXES = ['xidian.edu.cn'];

const parseOrigin = (value) => {
  const match = /^([a-zA-Z][a-zA-Z0-9+.-]*):\/\/([^/?#]+)/.exec(String(value || '').trim());
  if (!match) return null;
  const scheme = match[1].toLowerCase();
  const authority = match[2];
  // Strip userinfo ("https://evil.com@xidian.edu.cn" reads as evil.com to some
  // parsers and as xidian.edu.cn to others) and the port.
  const hostPart = authority.indexOf('@') >= 0 ? authority.slice(authority.lastIndexOf('@') + 1) : authority;
  const host = hostPart.replace(/^\[|\]$/g, '').split(':')[0].toLowerCase();
  if (!host) return null;
  return { scheme, host, hasUserinfo: authority.indexOf('@') >= 0 };
};

const selfOrigin = parseOrigin(baseUrl);

const isAllowedUrl = (value) => {
  const parsed = parseOrigin(value);
  if (!parsed) return false;
  if (parsed.hasUserinfo) return false;
  // Our own backend origin (it serves the unified-auth start/callback pages).
  if (selfOrigin && parsed.scheme === selfOrigin.scheme && parsed.host === selfOrigin.host) {
    return true;
  }
  if (parsed.scheme !== 'https') return false;
  return ALLOWED_HOST_SUFFIXES.some(
    (suffix) => parsed.host === suffix || parsed.host.endsWith(`.${suffix}`)
  );
};

Page({
  data: {
    url: ''
  },

  onLoad(options) {
    let raw = String((options && options.url) || '');
    try {
      raw = decodeURIComponent(raw);
    } catch (error) {
      // Malformed percent-encoding: keep the raw value, the allowlist below
      // will reject it anyway.
    }

    if (!isAllowedUrl(raw)) {
      wx.showToast({ title: '该链接不被允许打开', icon: 'none' });
      setTimeout(() => wx.navigateBack({ delta: 1 }), 800);
      return;
    }

    this.setData({ url: raw });
  }
});
