import { baseUrl } from '../../../config/env';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

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
    url: '',
    failedUrl: '',
    errorTitle: '',
    errorMessage: ''
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  onLoad(options) {
    let raw = String((options && options.url) || '');
    try {
      raw = decodeURIComponent(raw);
    } catch (error) {
      // Malformed percent-encoding: keep the raw value, the allowlist below
      // will reject it anyway.
    }

    // Refused links stay on a page that says so: opened from a share card
    // there is no page to go back to, and the old auto-back left a blank page.
    if (!isAllowedUrl(raw)) {
      this.setData({
        errorTitle: '该链接不被允许打开',
        errorMessage: '这里只能打开西电官方网站。'
      });
      return;
    }

    this.setData({ url: raw });
  },

  onLoadError() {
    this.setData({
      failedUrl: this.data.url,
      url: '',
      errorTitle: '页面加载失败',
      errorMessage: '请检查网络，或确认已连接校园网后重试。'
    });
  },

  retryOpen() {
    const url = this.data.failedUrl;
    if (!url) return;
    this.setData({ url, failedUrl: '', errorTitle: '', errorMessage: '' });
  },

  goBack() {
    if (getCurrentPages().length > 1) {
      wx.navigateBack({ delta: 1 });
      return;
    }
    wx.switchTab({ url: '/pages/campus/index' });
  }
});
