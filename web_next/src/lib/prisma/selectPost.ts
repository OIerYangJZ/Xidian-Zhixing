import { includeUserSummary } from './includeUserSummary';

export const selectPost = (userId: string | undefined) => ({
  id: true,
  userId: true,
  content: true,
  createdAt: true,
  viewCount: true,
  status: true,
  displayIdentity: true,
  spaceId: true,
  publishedAsClub: {
    select: {
      id: true,
      name: true,
      slug: true,
      avatar: true,
    },
  },
  ...includeUserSummary(),
  visualMedia: true,
  /**
   * Use postLikes to store the <PostLike>'s id of the user to the Post.
   * If there is a <PostLike> id, that means the user requesting has
   * liked the Post.
   */
  postLikes: {
    select: {
      id: true,
    },
    where: {
      userId,
    },
  },
  bookmarks: {
    select: { id: true },
    where: { userId: userId ?? '' },
  },
  reposts: {
    select: { id: true },
    where: { userId: userId ?? '' },
  },
  _count: {
    select: {
      postLikes: true,
      comments: true,
      reposts: true,
      bookmarks: true,
    },
  },
});
