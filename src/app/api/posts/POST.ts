/**
 * POST /api/posts
 * - Allows an authenticated user to create a post.
 */
import { serverWritePost } from '@/hooks/serverWritePost';

export async function POST(request: Request) {
  let formData: FormData;
  if (request.headers.get('content-type')?.includes('application/json')) {
    const body = (await request.json().catch(() => null)) as Record<string, unknown> | null;
    formData = new FormData();
    for (const key of ['content', 'displayIdentity']) {
      const value = body?.[key];
      if (typeof value === 'string') formData.set(key, value);
    }
  } else {
    formData = await request.formData();
  }
  return serverWritePost({ formData, type: 'create' });
}
