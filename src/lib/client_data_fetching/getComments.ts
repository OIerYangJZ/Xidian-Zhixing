import { GetComment } from '@/types/definitions';

export async function getComments({ postId, sort }: { postId: number; sort: 'hot' | 'time' }) {
  const res = await fetch(`/api/posts/${postId}/comments?sort=${sort}`);

  if (!res.ok) throw new Error('Error Getting Comments');
  return (await res.json()) as GetComment[];
}
