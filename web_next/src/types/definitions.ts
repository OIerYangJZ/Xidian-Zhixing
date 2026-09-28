/**
 * Shapes the UI components consume.
 *
 * These keep the names the components were written against (GetPost, GetUser,
 * GetComment, GetActivity), but every value now comes from the Python backend
 * through src/lib/backend/adapters.ts.  IDs are the backend's prefixed strings
 * ("p123", "u12", "cm45"); never parse them as numbers.
 */

export type VisualMediaType = 'PHOTO' | 'VIDEO';
export type DisplayIdentity = 'USER' | 'CLUB' | 'ANONYMOUS';
/** Moderation state as the author sees it; others only ever get PUBLISHED. */
export type PostStatus = 'PUBLISHED' | 'PENDING_REVIEW' | 'REMOVED';
/** Author-set progress on a post (求助 → 已解决 …). */
export type PostProgress = 'ongoing' | 'resolved' | 'closed';
export type SectionType = 'general' | 'college' | 'club';

export type ActivityType =
  | 'CREATE_FOLLOW'
  | 'POST_LIKE'
  | 'POST_FAVORITE'
  | 'POST_MENTION'
  | 'CREATE_COMMENT'
  | 'COMMENT_MENTION'
  | 'COMMENT_LIKE'
  | 'CREATE_REPLY'
  | 'REPLY_MENTION'
  | 'REPLY_LIKE'
  | 'POST_REPOST'
  | 'REPORT_RESULT'
  | 'SYSTEM';

export interface UserSummaryAfterSetUp {
  id: string;
  /** Profiles are addressed by id; kept under this name for the route code. */
  username: string;
  name: string;
  profilePhoto: string | null;
}

export interface GetUser {
  id: string;
  username: string;
  name: string;
  bio: string | null;
  website: string | null;
  showContactable: boolean;
  profilePhoto: string | null;
  coverPhoto: string | null;
  followerCount: number | null;
  followingCount: number | null;
  /** true when the signed-in user follows this user */
  isFollowing: boolean | null;
  isFollower: boolean;
  isOwnProfile: boolean;
  canFollow: boolean;
  canDirectMessage: boolean;
  isBlockedByMe: boolean;
  postCount: number;
  gender: string;
  college: string;
  major: string;
  verified: boolean;
  userLevelLabel: string;
}

export interface Mention {
  userId: string;
  nickname: string;
}

export interface GetVisualMedia {
  type: VisualMediaType;
  url: string;
  /** Upload id of an image already on the post; absent for one just picked. */
  uploadId?: string;
}

export interface VisualMediaModalType {
  visualMedia: GetVisualMedia[];
  initialSlide: number;
}

export interface GetPost {
  id: string;
  title: string;
  content: string | null;
  createdAt: string;
  viewCount: number;
  status: PostStatus;
  progress: PostProgress;
  displayIdentity: DisplayIdentity;
  /** Alias shown for anonymous posts; the author's nickname otherwise. */
  authorAlias: string;
  /** Shown when `user` is null but the author is not anonymous (one's own private post). */
  authorAvatarUrl: string | null;
  sectionType: SectionType;
  sectionId: string;
  sectionName: string;
  tags: string[];
  publishedAsClub: { id: string; name: string; slug: string; avatar: string | null } | null;
  isOwnPost: boolean;
  isLiked: boolean;
  isBookmarked: boolean;
  isReposted: boolean;
  /** People @-mentioned in the text; `@nickname` links to their profile. */
  mentions: Mention[];
  /** Last author edit, '' when never edited. */
  editedAt: string;
  /** Upload ids of the attached images, in order (for editing). */
  uploadedImageIds: string[];
  isPinned: boolean;
  isPrivate: boolean;
  allowComment: boolean;
  canMessageAuthor: boolean;
  /** null when the author is hidden (anonymous or private profile). */
  user: UserSummaryAfterSetUp | null;
  visualMedia: GetVisualMedia[];
  _count: {
    postLikes: number;
    comments: number;
    reposts: number;
    bookmarks: number;
  };
}

/**
 * Use `PostIds` when rendering a list of <Post>'s, this type
 * must be passed to <Post>, and <Post> must use the `id` to
 * check for queried post data using this `queryKey` format:
 * ['posts', string] where string is the post's id
 */
export interface PostId {
  id: string;
  commentsShown: boolean;
  feedEventKey?: string;
  feedCursor?: string;
  /** Set on a profile timeline when this entry is the profile owner's repost. */
  repostedBy?: { name: string | null; username: string | null };
}

export type PostIds = PostId[];

/** One loaded page of a <Posts> timeline, as kept in the React Query cache. */
export interface PostsPage {
  items: PostIds;
  /** Kept in the page itself: a remounted list must still know to load on. */
  hasMore: boolean;
}

export interface GetComment {
  id: string;
  postId: string;
  /** Directly replied-to comment; null at the top level. */
  parentId: string | null;
  content: string;
  createdAt: string;
  user: UserSummaryAfterSetUp;
  isLiked: boolean;
  isOwnComment: boolean;
  /** 洞主: written by the post's author */
  isPostAuthor: boolean;
  isAnonymous: boolean;
  isPending: boolean;
  mentions: Mention[];
  editedAt: string;
  _count: {
    commentLikes: number;
    replies: number;
  };
  repliesShown?: boolean;
}

export interface GetActivity {
  id: string;
  type: ActivityType;
  /** Post (or comment) the activity is about. */
  sourceId: string;
  targetId: string | null;
  /** Post to open when the activity is clicked. */
  postId: string;
  createdAt: string;
  isNotificationRead: boolean;
  sourceUser: UserSummaryAfterSetUp;
  targetUser: UserSummaryAfterSetUp;
  title?: string;
  content?: string | null;
}
export type GetActivities = GetActivity[];
