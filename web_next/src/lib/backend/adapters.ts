/**
 * Backend JSON → the shapes the UI components were written against.
 * Keep all field renaming here so components never see backend names.
 */
import type {
  ActivityType,
  GetActivity,
  GetComment,
  GetPost,
  GetUser,
  PostStatus,
  UserSummaryAfterSetUp,
} from '@/types/definitions';
import type { ApiComment, ApiMe, ApiNotification, ApiPost, ApiPublicProfile } from './types';

const orNull = (value: string | null | undefined) => value || null;

function postStatus(reviewStatus: ApiPost['reviewStatus']): PostStatus {
  if (reviewStatus === 'pending') return 'PENDING_REVIEW';
  if (reviewStatus === 'rejected') return 'REMOVED';
  return 'PUBLISHED';
}

export function toGetPost(post: ApiPost): GetPost {
  const isClub = post.publisherType === 'club';
  const identity = post.isAnonymous ? 'ANONYMOUS' : isClub ? 'CLUB' : 'USER';
  return {
    id: post.id,
    title: post.title || '',
    content: post.content || null,
    createdAt: post.createdAt,
    viewCount: post.viewCount,
    status: postStatus(post.reviewStatus),
    progress: post.status,
    displayIdentity: identity,
    authorAlias: post.authorAlias,
    sectionType: post.sectionType || 'general',
    sectionId: post.sectionId || 'general',
    sectionName: post.sectionName,
    tags: post.tags || [],
    publishedAsClub: isClub
      ? {
          id: post.publisherClubId,
          name: post.authorAlias,
          slug: post.publisherClubId,
          avatar: orNull(post.authorAvatarUrl),
        }
      : null,
    isOwnPost: post.isOwnPost,
    isLiked: post.liked,
    isBookmarked: post.favorited,
    isReposted: false,
    isPinned: post.isPinned,
    isPrivate: post.isPrivate,
    allowComment: post.allowComment,
    canMessageAuthor: post.canMessageAuthor,
    // authorUserId is "" whenever the viewer may not open the author's
    // profile (anonymous or private), which is exactly when to hide it.
    user: post.authorUserId
      ? {
          id: post.authorUserId,
          username: post.authorUserId,
          name: post.authorAlias,
          profilePhoto: orNull(post.authorAvatarUrl),
        }
      : null,
    visualMedia: (post.imageUrls || []).map((url) => ({ type: 'PHOTO', url })),
    _count: {
      postLikes: post.likeCount,
      comments: post.commentCount,
      reposts: 0,
      bookmarks: post.favoriteCount,
    },
  };
}

export function toGetUser(profile: ApiPublicProfile): GetUser {
  return {
    id: profile.id,
    username: profile.id,
    name: profile.nickname || profile.alias,
    bio: orNull(profile.bio),
    website: null,
    showContactable: profile.canDirectMessage,
    profilePhoto: orNull(profile.avatarUrl),
    coverPhoto: orNull(profile.backgroundImageUrl),
    followerCount: profile.followerCount,
    followingCount: profile.followingCount,
    isFollowing: profile.isOwnProfile ? null : profile.isFollowing,
    isFollower: profile.isFollower,
    isOwnProfile: profile.isOwnProfile,
    canFollow: profile.canFollow,
    canDirectMessage: profile.canDirectMessage,
    isBlockedByMe: profile.isBlockedByMe,
    postCount: profile.postCount,
    gender: profile.gender,
    college: profile.college,
    major: profile.major,
    verified: profile.verified,
    userLevelLabel: profile.userLevelLabel,
  };
}

/** The signed-in user, in the same shape as anyone else's profile. */
export function meToGetUser(me: ApiMe): GetUser {
  return {
    id: me.id,
    username: me.id,
    name: me.nickname || me.alias,
    bio: orNull(me.bio),
    website: null,
    showContactable: me.showContactable,
    profilePhoto: orNull(me.avatarUrl),
    coverPhoto: orNull(me.backgroundImageUrl),
    followerCount: me.followerCount,
    followingCount: me.followingCount,
    isFollowing: null,
    isFollower: false,
    isOwnProfile: true,
    canFollow: false,
    canDirectMessage: false,
    isBlockedByMe: false,
    postCount: me.postCount,
    gender: me.gender,
    college: me.college,
    major: me.major,
    verified: me.verified,
    userLevelLabel: me.userLevelLabel,
  };
}

const ANONYMOUS_AUTHOR = (alias: string): UserSummaryAfterSetUp => ({
  id: '',
  username: '',
  name: alias || '匿名同学',
  profilePhoto: null,
});

/**
 * Comments arrive as one flat list; `replies` counts direct children so the
 * thread UI can show "N 条回复" without a separate request.
 */
export function toGetComments(comments: ApiComment[]): GetComment[] {
  const childCount = new Map<string, number>();
  comments.forEach((comment) => {
    if (comment.parentId) childCount.set(comment.parentId, (childCount.get(comment.parentId) || 0) + 1);
  });
  return comments.map((comment) => ({
    id: comment.id,
    postId: comment.postId,
    parentId: comment.parentId || null,
    content: comment.content,
    createdAt: comment.createdAt,
    user: comment.authorUserId
      ? {
          id: comment.authorUserId,
          username: comment.authorUserId,
          name: comment.authorAlias,
          profilePhoto: orNull(comment.authorAvatarUrl),
        }
      : ANONYMOUS_AUTHOR(comment.authorAlias),
    isLiked: comment.liked,
    isOwnComment: comment.isOwnComment,
    isPostAuthor: comment.isPostAuthor,
    isAnonymous: comment.isAnonymous,
    isPending: comment.reviewStatus === 'pending',
    _count: {
      commentLikes: comment.likeCount,
      replies: childCount.get(comment.id) || 0,
    },
  }));
}

function activityType(notification: ApiNotification): ActivityType {
  switch (notification.type) {
    case 'comment':
      return 'CREATE_COMMENT';
    case 'reply':
      return 'CREATE_REPLY';
    case 'like':
      return notification.relatedType === 'comment' ? 'COMMENT_LIKE' : 'POST_LIKE';
    case 'favorite':
      return 'POST_FAVORITE';
    case 'report_result':
      return 'REPORT_RESULT';
    default:
      return 'SYSTEM';
  }
}

export function toGetActivity(notification: ApiNotification, me: UserSummaryAfterSetUp): GetActivity {
  const actor: UserSummaryAfterSetUp = notification.actorId
    ? {
        id: notification.actorId,
        username: notification.actorId,
        name: notification.actorAlias,
        profilePhoto: orNull(notification.actorAvatarUrl),
      }
    : ANONYMOUS_AUTHOR(notification.actorAlias || '系统通知');
  return {
    id: notification.id,
    type: activityType(notification),
    sourceId: notification.relatedId,
    targetId: notification.relatedType === 'comment' ? notification.relatedId : null,
    postId: notification.postId || (notification.relatedType === 'post' ? notification.relatedId : ''),
    createdAt: notification.createdAt,
    isNotificationRead: notification.isRead,
    sourceUser: actor,
    targetUser: me,
    title: notification.title,
    content: notification.content || null,
  };
}
