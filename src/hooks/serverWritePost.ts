import { selectPost } from '@/lib/prisma/selectPost';
import { formDataToObject } from '@/lib/formDataToObject';
import prisma from '@/lib/prisma/prisma';
import { NextResponse } from 'next/server';
import { Blob } from 'buffer';
import { PostStatus } from '@prisma/client';
import { GetPost } from '@/types/definitions';
import { isValidFileType } from '@/lib/isValidFileType';
import { postWriteSchema } from '@/lib/validations/post';
import { z } from 'zod';
import { toGetPost } from '@/lib/prisma/toGetPost';
import { getServerUser } from '@/lib/getServerUser';
import { convertMentionUsernamesToIds } from '@/lib/convertMentionUsernamesToIds';
import { mentionsActivityLogger } from '@/lib/mentionsActivityLogger';
import { deleteObject } from '@/lib/s3/deleteObject';
import { savePostFiles } from '@/lib/s3/savePostFiles';
import { verifyAccessToPost } from '@/app/api/posts/[postId]/verifyAccessToPost';
import { reviewPostSubmission } from '@/lib/moderation/reviewPost';

type Props =
  | { formData: FormData; type: 'create'; postId?: undefined }
  | { formData: FormData; type: 'edit'; postId: number };

function fileNameFromUrl(value: string) {
  try {
    const path = new URL(value).pathname;
    const encodedName = path.slice(path.lastIndexOf('/') + 1);
    return decodeURIComponent(encodedName);
  } catch {
    return '';
  }
}

const automaticReviewNote = (reasons: string[]) => `自动审核：${reasons.join('；')}`;

export async function serverWritePost({ formData, type, postId }: Props) {
  const [user] = await getServerUser();
  if (!user?.id) return NextResponse.json({}, { status: 401 });
  const userId = user.id;

  if (type === 'edit' && !(await verifyAccessToPost(postId))) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
  }

  try {
    const body = postWriteSchema.parse(formDataToObject(formData));
    const { content, files } = body;
    const filesArr = !files ? [] : Array.isArray(files) ? files : [files];
    const existingPost =
      type === 'edit'
        ? await prisma.post.findUnique({
            where: { id: postId },
            select: {
              visualMedia: { select: { fileName: true, userId: true } },
              moderationCases: {
                where: { status: 'OPEN' },
                select: { id: true, reportId: true, commentId: true, notes: true },
              },
            },
          })
        : null;

    if (type === 'edit' && !existingPost) return NextResponse.json({ error: 'Post not found.' }, { status: 404 });

    for (const file of filesArr) {
      if (typeof file === 'string') {
        const fileName = fileNameFromUrl(file);
        const isOwnedPostFile = existingPost?.visualMedia.some(
          (media) => media.fileName === fileName && media.userId === userId,
        );
        if (!fileName || !isOwnedPostFile) {
          return NextResponse.json({ error: 'Attachment does not belong to this post.' }, { status: 403 });
        }
      } else if (!isValidFileType(file.type)) {
        return NextResponse.json({ error: 'Invalid file type.' }, { status: 415 });
      }
    }

    const { str, usersMentioned } = await convertMentionUsernamesToIds({ str: content || '' });
    const newFiles = filesArr.filter((file): file is Blob => typeof file !== 'string');
    const moderation = await reviewPostSubmission(content || '', newFiles);
    if (moderation.decision === 'reject') {
      return NextResponse.json(
        {
          error: '内容命中平台禁止发布规则，请修改后重试。',
          code: 'POST_CONTENT_REJECTED',
          reasons: moderation.reasons,
        },
        { status: 422 },
      );
    }

    const savedFiles = await savePostFiles(filesArr);
    const mediaToCreate = savedFiles.map((savedFile) => ({
      type: savedFile.type,
      fileName: savedFile.fileName,
      userId,
    }));
    const savedFileNames = new Set(savedFiles.map(({ fileName }) => fileName));
    const newUploadFileNames = filesArr.flatMap((file, index) =>
      typeof file === 'string' || !savedFiles[index] ? [] : [savedFiles[index].fileName],
    );
    const filesToDelete =
      type === 'edit' ? existingPost!.visualMedia.filter(({ fileName }) => !savedFileNames.has(fileName)) : [];
    const pendingReview = moderation.decision === 'review';
    const otherOpenCase =
      type === 'edit' &&
      existingPost!.moderationCases.some((moderationCase) => !moderationCase.notes?.startsWith('自动审核：'));
    const postStatus: PostStatus = pendingReview || otherOpenCase ? 'HIDDEN' : 'PUBLISHED';
    let res;

    try {
      if (type === 'create') {
        res = await prisma.$transaction(async (tx) => {
          const created = await tx.post.create({
            data: {
              content: str,
              status: postStatus,
              ...(files !== undefined && { visualMedia: { create: mediaToCreate } }),
              ...(pendingReview && {
                moderationCases: { create: { openedById: userId, notes: automaticReviewNote(moderation.reasons) } },
              }),
              userId,
            },
            select: selectPost(userId),
          });
          return created;
        });
      } else {
        res = await prisma.$transaction(async (tx) => {
          const updated = await tx.post.update({
            where: { id: postId },
            data: {
              content: str,
              status: postStatus,
              visualMedia: { deleteMany: {}, create: mediaToCreate },
            },
            select: selectPost(userId),
          });

          const openAutomaticCase = await tx.moderationCase.findFirst({
            where: {
              postId,
              status: 'OPEN',
              reportId: null,
              commentId: null,
              notes: { startsWith: '自动审核：' },
            },
            select: { id: true },
          });
          if (pendingReview) {
            if (openAutomaticCase) {
              await tx.moderationCase.update({
                where: { id: openAutomaticCase.id },
                data: { notes: automaticReviewNote(moderation.reasons) },
              });
            } else {
              await tx.moderationCase.create({
                data: { postId, openedById: userId, notes: automaticReviewNote(moderation.reasons) },
              });
            }
          } else if (openAutomaticCase) {
            await tx.moderationCase.update({
              where: { id: openAutomaticCase.id },
              data: { status: 'DISMISSED', resolvedAt: new Date(), notes: '作者修改后自动复审通过。' },
            });
          }
          return updated;
        });
      }
    } catch (error) {
      await Promise.allSettled(newUploadFileNames.map((fileName) => deleteObject(fileName)));
      throw error;
    }

    await Promise.allSettled(filesToDelete.map(({ fileName }) => deleteObject(fileName)));

    if (!pendingReview) {
      await mentionsActivityLogger({
        usersMentioned,
        activity: { type: 'POST_MENTION', sourceUserId: userId, sourceId: res.id },
        isUpdate: type === 'edit',
      });
    }

    return NextResponse.json<GetPost>(await toGetPost(res, userId));
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(null, { status: 422, statusText: error.issues[0].message });
    }
    return NextResponse.json({ error: 'Error writing post.' }, { status: 500 });
  }
}
