/**
 * DELETE /api/posts/:postId
 * - Allows an authenticated user to delete a post.
 */

import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma/prisma';
import { verifyAccessToPost } from './verifyAccessToPost';

export async function DELETE(request: Request, props: { params: Promise<{ postId: string }> }) {
  const params = await props.params;
  const postId = parseInt(params.postId, 10);
  if (!(await verifyAccessToPost(postId))) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
  }

  const res = await prisma.post.update({
    where: {
      id: postId,
    },
    data: {
      status: 'DELETED_BY_AUTHOR',
      deletedAt: new Date(),
    },
    select: { id: true },
  });

  return NextResponse.json({ id: res.id });
}
