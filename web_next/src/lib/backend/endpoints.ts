/**
 * Typed wrappers over the backend routes the UI uses.  Components and hooks
 * call these instead of fetch(); everything returned is already adapted to
 * @/types/definitions.  Route semantics (envelopes, rate limits, id formats):
 * docs/backend-api-contract.md.
 */
import type { GetComment, GetPost, GetUser, PostProgress } from '@/types/definitions';
import { api } from './client';
import { meToGetUser, toGetComments, toGetPost, toGetUser } from './adapters';
import type {
  ApiActivity,
  ApiBlockedUser,
  ApiPage,
  ApiTimelineItem,
  ApiComment,
  ApiConversation,
  ApiDirectMessage,
  ApiFollowUser,
  ApiMe,
  ApiNotificationList,
  ApiNotificationType,
  ApiPost,
  ApiPostPage,
  ApiPublicProfile,
  ApiSectionTree,
  ApiUpload,
  ApiXidianAttempt,
} from './types';

// ---------------------------------------------------------------- auth

export const createXidianAttempt = (nextPath: string) =>
  api<ApiXidianAttempt>('/api/auth/xidian/session', { method: 'POST', body: { platform: 'web', nextPath } });

/** Hands out the token exactly once; never call twice for one attempt. */
export const consumeXidianAttempt = (attemptId: string) =>
  api<ApiXidianAttempt>(`/api/auth/xidian/session/${encodeURIComponent(attemptId)}`);

// ---------------------------------------------------------------- posts

export type PostSort = 'latest' | 'hot' | 'likes' | 'oldest';

export interface PostListQuery {
  page: number;
  limit: number;
  sort?: PostSort;
  keyword?: string;
  authorId?: string;
  sectionType?: string;
  sectionId?: string;
  /** Posts carrying this tag. */
  tag?: string;
  hasImage?: boolean;
}

export interface PostPage {
  posts: GetPost[];
  hasMore: boolean;
  total: number;
}

export async function listPosts(query: PostListQuery): Promise<PostPage> {
  const data = await api<ApiPostPage>('/api/posts', { query: { ...query } });
  return { posts: data.items.map(toGetPost), hasMore: data.hasMore, total: data.total };
}

/** Not paginated on the backend: the whole list in one page. */
export async function listFavoritePosts(): Promise<PostPage> {
  const posts = (await api<ApiPost[]>('/api/posts/favorites')).map(toGetPost);
  return { posts, hasMore: false, total: posts.length };
}

export async function listMyPosts(): Promise<GetPost[]> {
  return (await api<ApiPost[]>('/api/posts/mine')).map(toGetPost);
}

export const getPost = async (postId: string) => toGetPost(await api<ApiPost>(`/api/posts/${postId}`));

/** Rate limited, and repeated abuse signs the user out: once per detail open. */
export const recordPostView = (postId: string) =>
  api<{ ok: boolean; viewCount: number }>(`/api/posts/${postId}/view`, { method: 'POST' });

export interface CreatePostInput {
  title: string;
  content: string;
  tags?: string[];
  imageUploadIds?: string[];
  sectionType?: string;
  sectionId?: string;
  sectionName?: string;
  useAnonymousAlias?: boolean;
  anonymousAlias?: string;
  allowComment?: boolean;
  allowDm?: boolean;
  visibility?: 'public' | 'private';
  /** Optional; the backend stores 'none' when left out. */
  status?: PostProgress;
  /** Accounts @-mentioned in the text; the backend keeps only those it finds there. */
  mentionUserIds?: string[];
}

export interface EditPostInput {
  title: string;
  /** Omit to keep the text (a markdown post then stays markdown). */
  content?: string;
  /** The complete new image list; images left out are deleted.  Omit to keep them. */
  imageUploadIds?: string[];
  mentionUserIds: string[];
  status?: PostProgress;
}

export const editPost = async (postId: string, input: EditPostInput) =>
  toGetPost(await api<ApiPost>(`/api/posts/${postId}`, { method: 'PATCH', body: input }));

export const setPostReposted = (postId: string, reposted: boolean) =>
  api<{ reposted: boolean; repostCount: number }>(`/api/posts/${postId}/repost`, {
    method: 'POST',
    body: { reposted },
  });

export interface TimelineEntry {
  post: GetPost;
  repostedBy: { userId: string; nickname: string } | null;
  eventKey: string;
}

/** A user's posts and reposts, newest first (profile 动态 tab). */
export async function listTimeline(
  userId: string,
  page: number,
  limit: number,
): Promise<{ entries: TimelineEntry[]; hasMore: boolean }> {
  const data = await api<ApiPage<ApiTimelineItem>>(`/api/users/${userId}/timeline`, { query: { page, limit } });
  return {
    entries: data.items.map((item) => ({
      post: toGetPost(item),
      repostedBy: item.repostedBy,
      eventKey: item.eventKey,
    })),
    hasMore: data.hasMore,
  };
}

/** What the signed-in user did, newest first (profile 互动 tab). */
export const listMyActivity = (page: number, limit: number) =>
  api<ApiPage<ApiActivity>>('/api/users/me/activity', { query: { page, limit } });

export const createPost = async (input: CreatePostInput) =>
  toGetPost(await api<ApiPost>('/api/posts', { method: 'POST', body: input }));

export const setPostProgress = async (postId: string, status: PostProgress) =>
  toGetPost(await api<ApiPost>(`/api/posts/${postId}`, { method: 'PATCH', body: { status } }));

export const deletePost = (postId: string) => api<{ ok: boolean }>(`/api/posts/${postId}`, { method: 'DELETE' });

export const setPostLiked = (postId: string, liked: boolean) =>
  api<{ liked: boolean; likeCount: number }>(`/api/posts/${postId}/like`, { method: 'POST', body: { liked } });

export const setPostFavorited = (postId: string, favorited: boolean) =>
  api<{ favorited: boolean; favoriteCount: number }>(`/api/posts/${postId}/favorite`, {
    method: 'POST',
    body: { favorited },
  });

export const getAnonymousAlias = () => api<{ alias: string }>('/api/posts/anonymous-alias');

export const getSectionTree = () => api<ApiSectionTree>('/api/sections/tree');

// ---------------------------------------------------------------- uploads

/** The upload routes take base64 (a data: URI is accepted as-is). */
function readAsDataUrl(file: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

export async function uploadImage(file: Blob, fileName: string, postId?: string): Promise<ApiUpload> {
  const dataBase64 = await readAsDataUrl(file);
  return api<ApiUpload>('/api/uploads/images', {
    method: 'POST',
    body: { dataBase64, fileName, contentType: file.type || undefined, postId },
  });
}

// ---------------------------------------------------------------- comments

export type CommentSort = 'latest' | 'hot';

export async function listComments(postId: string, sort: CommentSort): Promise<GetComment[]> {
  return toGetComments(await api<ApiComment[]>(`/api/posts/${postId}/comments`, { query: { sort } }));
}

export async function createComment(
  postId: string,
  content: string,
  parentId?: string,
  mentionUserIds: string[] = [],
): Promise<GetComment> {
  const comment = await api<ApiComment>(`/api/posts/${postId}/comments`, {
    method: 'POST',
    body: { content, parentId: parentId || undefined, mentionUserIds },
  });
  return toGetComments([comment])[0];
}

export async function editComment(commentId: string, content: string, mentionUserIds: string[]): Promise<GetComment> {
  const comment = await api<ApiComment>(`/api/comments/${commentId}`, {
    method: 'PATCH',
    body: { content, mentionUserIds },
  });
  return toGetComments([comment])[0];
}

export const deleteComment = (commentId: string) =>
  api<{ ok: boolean }>(`/api/comments/${commentId}`, { method: 'DELETE' });

export const setCommentLiked = (commentId: string, liked: boolean) =>
  api<{ liked: boolean }>(`/api/comments/${commentId}/like`, { method: 'POST', body: { liked } });

// ---------------------------------------------------------------- users

export const getMe = () => api<ApiMe>('/api/users/me');

export async function getUser(userId: string, meId?: string): Promise<GetUser> {
  if (meId && userId === meId) return meToGetUser(await getMe());
  return toGetUser(await api<ApiPublicProfile>(`/api/users/${userId}`));
}

export async function searchUsers(keyword: string): Promise<GetUser[]> {
  if (!keyword.trim()) return [];
  return (await api<ApiPublicProfile[]>('/api/users/search', { query: { keyword } })).map(toGetUser);
}

export const followUser = (userId: string) => api(`/api/users/${userId}/follow`, { method: 'POST' });
export const unfollowUser = (userId: string) => api(`/api/users/${userId}/unfollow`, { method: 'POST' });

/** Only the signed-in user's own lists exist on the backend. */
export const listMyFollowing = () => api<ApiFollowUser[]>('/api/users/me/following');
export const listMyFollowers = () => api<ApiFollowUser[]>('/api/users/me/followers');

export const updateMe = (patch: Partial<Pick<ApiMe, 'nickname' | 'bio' | 'gender' | 'major' | 'backgroundImageUrl'>>) =>
  api('/api/users/me', { method: 'PATCH', body: patch });

export async function uploadAvatar(file: Blob, fileName: string): Promise<{ avatarUrl: string }> {
  const dataBase64 = await readAsDataUrl(file);
  return api('/api/users/avatar', { method: 'POST', body: { dataBase64, fileName, contentType: file.type } });
}

/** Cancellation is reviewed by an admin; DELETE /api/users/me is refused on purpose. */
export const requestAccountCancellation = (reason?: string) =>
  api<{ id: string; status: string }>('/api/users/me/cancellation-request', { method: 'POST', body: { reason } });

export const listBlocks = () => api<ApiBlockedUser[]>('/api/users/me/blocks');
export const blockUser = (targetUserId: string) =>
  api('/api/users/me/blocks', { method: 'POST', body: { targetUserId } });
export const unblockUser = (userId: string) => api(`/api/users/me/blocks/${userId}`, { method: 'DELETE' });

export const updatePrivacy = (patch: { allowStrangerDm?: boolean; showContactable?: boolean }) =>
  api('/api/users/privacy', { method: 'PATCH', body: patch });

export const updateNotificationPreferences = (patch: Partial<Record<`notify${string}`, boolean>>) =>
  api('/api/users/notification-preferences', { method: 'PATCH', body: patch });

// ---------------------------------------------------------------- notifications

export const listNotifications = () => api<ApiNotificationList>('/api/notifications');

export const markNotificationRead = (notificationId: string) =>
  api(`/api/notifications/${notificationId}/read`, { method: 'POST' });

export const markAllNotificationsRead = (type?: ApiNotificationType) =>
  api<{ ok: boolean; marked: number }>('/api/notifications/read-all', { method: 'POST', body: type ? { type } : {} });

// ---------------------------------------------------------------- messages

export const listConversations = () => api<ApiConversation[]>('/api/messages/conversations');

export const openDirectConversation = (targetUserId: string, postId?: string) =>
  api<ApiConversation>('/api/messages/conversations/direct', {
    method: 'POST',
    body: { targetUserId, postId: postId || undefined },
  });

/** Also marks the conversation read. */
export const listMessages = (conversationId: string) =>
  api<ApiDirectMessage[]>(`/api/messages/conversations/${conversationId}/messages`);

export const sendMessage = (conversationId: string, content: string, replyToId?: string) =>
  api<ApiDirectMessage>(`/api/messages/conversations/${conversationId}/messages`, {
    method: 'POST',
    body: { content, replyToId: replyToId || undefined },
  });

export const recallMessage = (conversationId: string, messageId: string) =>
  api(`/api/messages/messages/${messageId}/recall`, { method: 'DELETE', query: { conversationId } });

export const deleteConversation = (conversationId: string) =>
  api(`/api/messages/conversations/${conversationId}`, { method: 'DELETE' });

export interface HotTopic {
  id: string;
  rank: number;
  postId: string;
  title: string;
  summary: string;
  hotScore: number;
  sectionName: string;
}

/** Today's ranking, rebuilt on the server. */
export const listHotTopics = () => api<HotTopic[]>('/api/hot-topics');

// ---------------------------------------------------------------- campus

/** Admin-configured catalogue; `status` is display text such as "待接入". */
export interface ApiCampusService {
  id: string;
  slug: string;
  name: string;
  groupId: string;
  groupName: string;
  kind: string;
  iconKey: string;
  authType: string;
  authReady: boolean;
  status: string;
  description: string;
  requiredAccess: string[];
  features: string[];
  dataFields: string[];
  calendarSource: string;
  emptyText: string;
  mapIds: string[];
  actions: { label: string; type: string; url: string; path: string }[];
  enabled: boolean;
  sortOrder: number;
}

export const listCampusServices = () => api<ApiCampusService[]>('/api/campus/services');
export const getCampusService = (idOrSlug: string) =>
  api<ApiCampusService>(`/api/campus/services/${encodeURIComponent(idOrSlug)}`);

// ---------------------------------------------------------------- AI

export interface AiCitation {
  sourceType: string;
  targetType: 'post' | 'knowledge';
  targetId: string;
  title: string;
  summary: string;
  sourceUrl: string;
  jumpUrl: string;
}

export interface AiAnswer {
  answer: string;
  traceId: string;
  citations: AiCitation[];
}

/**
 * Not streamed: one JSON body, possibly after a long wait (the Flutter client
 * allows 165 s).  History lives on the client; the server keeps the last 8
 * turns of what is sent.  Cancelling makes this reject with 409 {cancelled}.
 */
export const askAi = (
  content: string,
  history: { role: 'user' | 'assistant'; content: string }[],
  requestId: string,
  signal?: AbortSignal,
) => api<AiAnswer>('/api/ai/chat', { method: 'POST', body: { content, messages: history, requestId }, signal });

export const cancelAi = (requestId: string) =>
  api<{ cancelled: boolean }>('/api/ai/chat/cancel', { method: 'POST', body: { requestId } });

// ---------------------------------------------------------------- reports, appeals

export const REPORT_REASONS = [
  '广告引流',
  '人身攻击',
  '违规内容',
  '垃圾信息',
  '色情低俗',
  '虚假信息',
  '侵犯隐私',
  '其他',
] as const;
export type ReportReason = (typeof REPORT_REASONS)[number];

export const createReport = (input: {
  targetType: 'post' | 'comment' | 'user';
  targetId: string;
  reason: ReportReason;
  description?: string;
}) => api<{ ok: boolean; id: string }>('/api/reports', { method: 'POST', body: input });

export interface MyAppeal {
  appeal: null | {
    id: string;
    appealType: string;
    title: string;
    content: string;
    status: string;
    adminNote: string;
    createdAt: string;
    handledAt: string;
  };
  banned: boolean;
  canSubmit: boolean;
  supportEmail: string;
}

export const getMyAppeal = () => api<MyAppeal>('/api/appeals/mine');

export const submitBanAppeal = (email: string, content: string) =>
  api<{ ok: boolean; id: string }>('/api/appeals', {
    method: 'POST',
    body: { email, appealType: 'ban_revoke', content },
  });

export const submitFeedback = (content: string, contact?: string, category?: string) =>
  api('/api/feedback', { method: 'POST', body: { content, contact, category } });
