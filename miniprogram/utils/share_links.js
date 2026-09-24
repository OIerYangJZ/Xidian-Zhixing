import { baseUrl } from '../config/env';

// Public short links: https://<site>/p/<postId> and https://<site>/u/<userId>.
// Keep the format in step with flutter_app/lib/core/navigation/share_links.dart.
const SHARE_LINK_PATH = /\/([pu])\/([A-Za-z0-9_-]{1,64})\/?(?:[?#]|$)/;

const siteLink = (kind, id) =>
  `${String(baseUrl || '').replace(/\/$/, '')}/${kind}/${encodeURIComponent(id)}`;

export const postShareLink = (postId) => siteLink('p', postId);
export const userShareLink = (userId) => siteLink('u', userId);

// A QR code of a link opens the mini program with the scanned URL, encoded,
// in the page's `q` option. Page options pass through navigation without
// being decoded, so after the login redirect the URL can carry one more layer
// of encoding; decode until it stops changing.
const scannedLink = (q) => {
  let url = String(q || '');
  for (let i = 0; i < 3 && /%[0-9a-f]{2}/i.test(url); i += 1) {
    try {
      url = decodeURIComponent(url);
    } catch (error) {
      return null;
    }
  }
  const match = url.match(SHARE_LINK_PATH);
  return match ? { kind: match[1], id: match[2] } : null;
};

const scannedId = (kind) => (q) => {
  const link = scannedLink(q);
  return link && link.kind === kind ? link.id : '';
};

export const postIdFromScannedLink = scannedId('p');
export const userIdFromScannedLink = scannedId('u');
