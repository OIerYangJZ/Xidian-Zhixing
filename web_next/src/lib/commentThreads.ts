import type { GetComment } from '@/types/definitions';

export interface CommentReplyItem extends GetComment {
  /** Set when the reply answers another reply rather than the thread's root. */
  replyToName: string | null;
}

export interface CommentThread {
  root: GetComment;
  replies: CommentReplyItem[];
}

/**
 * The backend returns every comment of a post in one flat list, `parentId`
 * pointing at the directly replied-to comment at any depth.  The UI shows two
 * levels, so each reply is filed under the root of its chain, in the order it
 * was written.  A reply whose parent was deleted becomes a root itself.
 */
export function buildCommentThreads(comments: GetComment[]): CommentThread[] {
  const byId = new Map(comments.map((comment) => [comment.id, comment]));
  const rootOf = (comment: GetComment): GetComment => {
    let current = comment;
    const seen = new Set<string>();
    while (current.parentId && byId.has(current.parentId) && !seen.has(current.id)) {
      seen.add(current.id);
      current = byId.get(current.parentId)!;
    }
    return current;
  };

  const threads = new Map<string, CommentThread>();
  comments.forEach((comment) => {
    const root = rootOf(comment);
    if (root.id === comment.id)
      threads.set(comment.id, { root: comment, replies: threads.get(comment.id)?.replies ?? [] });
  });
  comments.forEach((comment) => {
    const root = rootOf(comment);
    if (root.id === comment.id) return;
    const parent = comment.parentId ? byId.get(comment.parentId) : undefined;
    threads.get(root.id)?.replies.push({
      ...comment,
      replyToName: parent && parent.id !== root.id ? parent.user.name : null,
    });
  });

  return [...threads.values()].map((thread) => ({
    root: { ...thread.root, _count: { ...thread.root._count, replies: thread.replies.length } },
    replies: thread.replies.sort((a, b) => a.createdAt.localeCompare(b.createdAt)),
  }));
}
