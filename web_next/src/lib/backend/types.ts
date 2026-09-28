/**
 * JSON shapes the Python backend returns, field for field.  The UI never uses
 * these directly: adapters.ts turns them into the types in @/types/definitions.
 */

export interface ApiMe {
  id: string;
  alias: string;
  nickname: string;
  studentId: string;
  email: string;
  avatarUrl: string;
  backgroundImageUrl: string;
  bio: string;
  gender: string;
  college: string;
  major: string;
  verified: boolean;
  banned: boolean;
  muted: boolean;
  deleted: boolean;
  allowStrangerDm: boolean;
  showContactable: boolean;
  notifyComment: boolean;
  notifyReply: boolean;
  notifyLike: boolean;
  notifyFavorite: boolean;
  notifyRepost: boolean;
  notifyMention: boolean;
  notifyReportResult: boolean;
  notifySystem: boolean;
  favoriteCount: number;
  postCount: number;
  followingCount: number;
  followerCount: number;
  userLevel: number;
  userLevelLabel: string;
  isLevelOneUser: boolean;
  createdAt: string;
}

export interface ApiPublicProfile {
  id: string;
  alias: string;
  nickname: string;
  avatarUrl: string;
  verified: boolean;
  userLevel: number;
  userLevelLabel: string;
  postCount: number;
  followingCount: number;
  followerCount: number;
  isFollowing: boolean;
  isFollower: boolean;
  isOwnProfile: boolean;
  canFollow: boolean;
  isBlockedByMe: boolean;
  bio: string;
  gender: string;
  college: string;
  major: string;
  backgroundImageUrl: string;
  canDirectMessage: boolean;
}

export interface ApiFollowUser {
  userId: string;
  nickname: string;
  avatarUrl: string;
  isFollowing: boolean;
  isFollower: boolean;
}

export interface ApiBlockedUser {
  id: string;
  nickname: string;
  avatarUrl: string;
  bio: string;
  blockedAt: string;
  timeText: string;
}

export interface ApiPost {
  id: string;
  title: string;
  content: string;
  contentFormat: 'plain' | 'markdown';
  markdownSource: string;
  tags: string[];
  authorAlias: string;
  isAnonymous: boolean;
  authorAvatarUrl: string;
  authorUserId: string;
  createdAt: string;
  updatedAt: string;
  hasImage: boolean;
  imageUrls: string[];
  uploadedImageIds: string[];
  commentCount: number;
  likeCount: number;
  favoriteCount: number;
  viewCount: number;
  sectionType: 'general' | 'college' | 'club' | '';
  sectionId: string;
  sectionName: string;
  publisherType: 'user' | 'club';
  publisherClubId: string;
  liked: boolean;
  favorited: boolean;
  repostCount: number;
  reposted: boolean;
  mentions: ApiMention[];
  editedAt: string;
  status: 'none' | 'ongoing' | 'resolved' | 'closed';
  reviewStatus: 'approved' | 'pending' | 'rejected' | 'resolved';
  allowComment: boolean;
  allowDm: boolean;
  visibility: 'public' | 'private';
  isPrivate: boolean;
  isPinned: boolean;
  canViewAuthorProfile: boolean;
  canFollowAuthor: boolean;
  isFollowingAuthor: boolean;
  canMessageAuthor: boolean;
  isOwnPost: boolean;
}

export interface ApiMention {
  userId: string;
  nickname: string;
}

/** A /api/users/<id>/timeline item: a post, possibly as someone's repost. */
export interface ApiTimelineItem extends ApiPost {
  repostedBy: ApiMention | null;
  eventKey: string;
  eventAt: string;
}

export interface ApiPage<T> {
  items: T[];
  page: number;
  limit: number;
  total: number;
  hasMore: boolean;
}

export type ApiActivityType = 'post' | 'comment' | 'like_post' | 'like_comment' | 'favorite' | 'repost' | 'follow';

export interface ApiActivity {
  id: string;
  type: ApiActivityType;
  createdAt: string;
  post?: { id: string; title: string };
  commentId?: string;
  content?: string;
  isAnonymous?: boolean;
  user?: ApiMention;
}

export interface ApiPostPage {
  items: ApiPost[];
  page: number;
  limit: number;
  total: number;
  hasMore: boolean;
}

export interface ApiComment {
  id: string;
  postId: string;
  content: string;
  authorAlias: string;
  authorId: string;
  authorUserId: string;
  authorAvatarUrl: string;
  isOwnComment: boolean;
  isPostAuthor: boolean;
  likeCount: number;
  liked: boolean;
  createdAt: string;
  isAnonymous: boolean;
  reviewStatus: string;
  parentId: string;
  mentions: ApiMention[];
  editedAt: string;
}

export type ApiNotificationType =
  | 'comment'
  | 'reply'
  | 'like'
  | 'favorite'
  | 'repost'
  | 'mention'
  | 'report_result'
  | 'system';

export interface ApiNotification {
  id: string;
  type: string;
  title: string;
  content: string;
  relatedType: 'post' | 'comment' | '';
  relatedId: string;
  postId: string;
  actorId: string;
  actorAlias: string;
  actorAvatarUrl: string;
  createdAt: string;
  readAt: string;
  isRead: boolean;
}

export interface ApiNotificationList {
  items: ApiNotification[];
  unreadCount: number;
  unreadByType: Record<ApiNotificationType, number>;
}

export interface ApiConversation {
  id: string;
  peerUserId: string;
  name: string;
  avatarUrl: string;
  lastMessage: string;
  timeText: string;
  unreadCount: number;
  hasUnread: boolean;
  blockedByMe: boolean;
  blockedByPeer: boolean;
  awaitingReply: boolean;
}

export interface ApiDirectMessage {
  id: string;
  content: string;
  createdAt: string;
  timeText: string;
  fromMe: boolean;
  senderUserId: string;
  senderAlias: string;
  readAt: string;
  isRead: boolean;
  deliveryStatus: 'sent' | 'read' | 'recalled';
  canRecall: boolean;
  recalled: boolean;
  replyToId: string | null;
  replyToSender: string | null;
  replyToContent: string | null;
}

export interface ApiUpload {
  id: string;
  url: string;
  status: 'approved' | 'risk' | 'rejected';
  moderationReason: string;
}

/** Named by `sectionId` alone; the backend exposes no other id. */
export interface ApiSection {
  sectionType: 'general' | 'college' | 'club';
  sectionId: string;
  sectionName: string;
  name: string;
  description: string;
  ruleText: string;
  enabled: boolean;
  sortOrder: number;
}

export interface ApiSectionTree {
  sections: ApiSection[];
  general: ApiSection[];
  colleges: ApiSection[];
  clubs: ApiSection[];
}

export interface ApiXidianAttempt {
  attemptId: string;
  status: 'pending' | 'authenticated' | 'failed';
  platform: string;
  authorizeUrl?: string;
  message?: string;
  token?: string;
  banned?: boolean;
}
