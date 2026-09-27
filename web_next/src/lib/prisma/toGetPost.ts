/**
 * Use this function to convert the result of using the `./selectPost`
 * in a Prisma `post` find query, to the <GetPost> type.
 */
import { FindPostResult, GetPost, GetVisualMedia } from '@/types/definitions';
import { convertMentionUsernamesToIds } from '../convertMentionUsernamesToIds';
import { fileNameToUrl } from '../s3/fileNameToUrl';

export async function toGetPost(findPostResult: FindPostResult, viewerUserId?: string): Promise<GetPost> {
  /**
   * Exclude the `postLikes` property as this is not needed in <GetPost>,
   * it is only used to determine whether the user requesting the post
   * has liked the post or not.
   */
  const { postLikes, bookmarks, reposts, content, userId: authorUserId, ...rest } = findPostResult;

  // Convert the `@` `id` mentions back to usernames
  const { str } = await convertMentionUsernamesToIds({
    str: content || '',
    reverse: true,
  });

  const visualMedia: GetVisualMedia[] = rest.visualMedia.map(({ type, fileName }) => ({
    type,
    url: fileNameToUrl(fileName) as string,
  }));

  return {
    ...rest,
    user:
      rest.displayIdentity === 'USER'
        ? {
            id: rest.user.id,
            username: rest.user.username!,
            name: rest.user.name!,
            profilePhoto: fileNameToUrl(rest.user.profilePhoto),
          }
        : null,
    publishedAsClub: rest.publishedAsClub
      ? { ...rest.publishedAsClub, avatar: fileNameToUrl(rest.publishedAsClub.avatar) }
      : null,
    visualMedia,
    content: str,
    isLiked: postLikes.length > 0,
    isBookmarked: bookmarks.length > 0,
    isReposted: reposts.length > 0,
    isOwnPost: authorUserId === viewerUserId,
  };
}
