import { favoritePost, togglePostLike, unfavoritePost } from '../api/posts';

export const togglePostLikeInList = async (posts, index) => {
  const post = posts[Number(index)];
  if (!post || !post.id) return posts;

  const result = await togglePostLike(post.id, Boolean(post.liked || post.isLiked));
  const liked = Boolean(result.liked);
  const nextPosts = posts.slice();
  nextPosts[Number(index)] = {
    ...post,
    liked,
    isLiked: liked,
    likeCount: Math.max(0, Number(post.likeCount || 0) + (liked ? 1 : -1))
  };
  return nextPosts;
};

export const togglePostFavoriteInList = async (posts, index) => {
  const post = posts[Number(index)];
  if (!post || !post.id) return posts;

  const favorited = Boolean(post.favorited || post.isFavorited);
  const result = favorited
    ? await unfavoritePost(post.id)
    : await favoritePost(post.id);
  const nextFavorited = !favorited;
  const nextPosts = posts.slice();
  nextPosts[Number(index)] = {
    ...post,
    favorited: nextFavorited,
    isFavorited: nextFavorited,
    favoriteCount: Number(result.favoriteCount)
  };
  return nextPosts;
};
