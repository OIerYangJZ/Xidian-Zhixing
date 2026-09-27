import { FindUserResult, GetUser } from '@/types/definitions';
import { fileNameToUrl } from '../s3/fileNameToUrl';

export const toGetUser = (findUserResult: FindUserResult): GetUser => ({
  id: findUserResult.id,
  name: findUserResult.name!,
  username: findUserResult.username!,
  bio: findUserResult.bio,
  website: findUserResult.website,
  showContactable: findUserResult.showContactable,
  profilePhoto: fileNameToUrl(findUserResult.profilePhoto),
  coverPhoto: fileNameToUrl(findUserResult.coverPhoto),
  followerCount: findUserResult._count.followers,
  followingCount: findUserResult._count.following,
  isFollowing: findUserResult.followers.length === 1,
});
