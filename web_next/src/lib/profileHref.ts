/**
 * In-app links to pages keyed by a runtime id.  The site is a static export,
 * so ids travel as query parameters on real pages (/post?id=p1) rather than
 * as path segments that would have no HTML file.  The share links already
 * handed out, /p/<id> and /u/<id>, are redirected here by Nginx.
 */

/** A user's profile (or one of its tabs).  An empty id has no page: anonymous or hidden. */
export function profileHref(userId: string | null | undefined, tab?: string): string | null {
  if (!userId) return null;
  const id = encodeURIComponent(userId);
  return tab ? `/u/${tab}?id=${id}` : `/u?id=${id}`;
}

export function postHref(postId: string, commentId?: string): string {
  const query = new URLSearchParams({ id: postId });
  if (commentId) query.set('comment', commentId);
  return `/post?${query.toString()}`;
}

export function tagHref(tag: string): string {
  return `/tag?name=${encodeURIComponent(tag)}`;
}

export function campusServiceHref(serviceId: string): string {
  return `/campus/service?id=${encodeURIComponent(serviceId)}`;
}
