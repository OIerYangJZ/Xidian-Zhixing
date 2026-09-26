/**
 * POST /api/posts/:postId/comments
 * - Allows an authenticated user to comment on a post specified
 * by the :postId.
 */

import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma/prisma';
import { FindCommentResult } from '@/types/definitions';
import { commentWriteSchema } from '@/lib/validations/comment';
import { z } from 'zod';
import { getServerUser } from '@/lib/getServerUser';
import { includeToComment } from '@/lib/prisma/includeToComment';
import { toGetComment } from '@/lib/prisma/toGetComment';
import { convertMentionUsernamesToIds } from '@/lib/convertMentionUsernamesToIds';
import { mentionsActivityLogger } from '@/lib/mentionsActivityLogger';
import { assessPostText } from '@/lib/moderation/text';

export async function POST(request: Request, props: { params: Promise<{ postId: string }> }) {
  const params = await props.params;
  const [user] = await getServerUser();
  if (!user) return NextResponse.json({}, { status: 401 });
  const userId = user.id;
  const postId = parseInt(params.postId, 10);

  try {
    const body = await request.json();
    let { content } = commentWriteSchema.parse(body);
    const moderation = assessPostText(content);
    if (moderation.decision !== 'approve') {
      return NextResponse.json(
        { error: '评论命中平台审核规则，请修改后重试。', reasons: moderation.reasons },
        { status: 422 },
      );
    }
    const post = await prisma.post.findFirst({
      where: { id: postId, OR: [{ status: 'PUBLISHED' }, { userId }] },
      select: { userId: true },
    });
    if (!post) return NextResponse.json({ error: 'Post not found.' }, { status: 404 });
    const block = await prisma.userBlock.findFirst({
      where: {
        OR: [
          { blockerId: userId, blockedId: post.userId },
          { blockerId: post.userId, blockedId: userId },
        ],
      },
      select: { id: true },
    });
    if (block) return NextResponse.json({ error: 'This post is unavailable.' }, { status: 404 });

    const { str, usersMentioned } = await convertMentionUsernamesToIds({
      str: content,
    });
    content = str;

    const res: FindCommentResult = await prisma.comment.create({
      data: {
        content,
        userId,
        postId,
      },
      include: includeToComment(userId),
    });

    // Record a 'CREATE_COMMENT' activity
    // Find the owner of the post
    await prisma.activity.create({
      data: {
        type: 'CREATE_COMMENT',
        sourceId: res.id,
        sourceUserId: userId,
        targetId: postId,
        targetUserId: post.userId,
      },
    });

    // Log the 'COMMENT_MENTION' activity if applicable
    await mentionsActivityLogger({
      usersMentioned,
      activity: {
        type: 'COMMENT_MENTION',
        sourceUserId: userId,
        sourceId: res.id,
        targetId: res.postId,
      },
      isUpdate: false,
    });

    return NextResponse.json(await toGetComment(res));
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(null, {
        status: 422,
        statusText: error.issues[0].message || 'Input validation error',
      });
    }

    return NextResponse.json(null, { status: 500 });
  }
}
