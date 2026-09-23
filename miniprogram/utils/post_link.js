import { baseUrl } from '../config/env';

// Public short link for one post: https://<site>/p/<postId>. Keep the format
// in step with flutter_app/lib/core/navigation/post_link.dart.
const POST_LINK_PATH = /\/p\/([A-Za-z0-9_-]{1,64})\/?(?:[?#]|$)/;

export const postShareLink = (postId) =>
  `${String(baseUrl || '').replace(/\/$/, '')}/p/${encodeURIComponent(postId)}`;

// A QR code of the link opens the mini program with the scanned URL, encoded,
// in the page's `q` option. Page options pass through navigation without
// being decoded, so after the login redirect the URL can carry one more layer
// of encoding; decode until it stops changing.
export const postIdFromScannedLink = (q) => {
  let url = String(q || '');
  for (let i = 0; i < 3 && /%[0-9a-f]{2}/i.test(url); i += 1) {
    try {
      url = decodeURIComponent(url);
    } catch (error) {
      return '';
    }
  }
  const match = url.match(POST_LINK_PATH);
  return match ? match[1] : '';
};
