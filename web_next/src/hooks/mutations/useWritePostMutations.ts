import { Query, useMutation, useQueryClient } from '@tanstack/react-query';
import { GetVisualMedia, DisplayIdentity, GetPost, PostProgress } from '@/types/definitions';
import { createPost, editPost, uploadImage } from '@/lib/backend/endpoints';
import { mentionIdsIn } from '@/lib/mentions';
import { revokeVisualMediaObjectUrls } from '@/lib/revokeVisualMediaObjectUrls';
import { useToast } from '../useToast';
import { useErrorNotifier } from '../useErrorNotifier';

export interface PostDraft {
  title: string;
  content: string;
  visualMedia: GetVisualMedia[];
  displayIdentity: DisplayIdentity;
  anonymousAlias: string;
  section: { sectionType: string; sectionId: string; sectionName: string };
  progress: PostProgress;
}

/** Timelines a new post can appear in: the feed and the author's profile. */
const isTimeline = (query: Query) => {
  const [head, second, third] = query.queryKey;
  return (head === 'posts' && second === 'feed') || third === 'posts';
};

/** Upload the images that are new to the post; keep the ids of the others. */
async function uploadIdsFor(visualMedia: GetVisualMedia[]): Promise<string[]> {
  const ids: string[] = [];
  /* eslint-disable no-await-in-loop -- one by one: uploads are rate limited */
  for (const [index, media] of visualMedia.entries()) {
    if (media.uploadId) {
      ids.push(media.uploadId);
    } else {
      const file = await fetch(media.url).then((r) => r.blob());
      const upload = await uploadImage(file, `image-${index + 1}`);
      if (upload.status === 'rejected') {
        throw new Error(upload.moderationReason || '有图片未通过审核，请更换后再发布');
      }
      ids.push(upload.id);
    }
  }
  /* eslint-enable no-await-in-loop */
  return ids;
}

/**
 * Publishing a new post, or (with `editing`) saving an edit of an existing
 * one.  The identity and section of a post are fixed once it is published.
 */
export function useWritePostMutations({
  draft,
  editing,
  exitCreatePostModal,
}: {
  draft: PostDraft;
  editing: GetPost | null;
  exitCreatePostModal: () => void;
}) {
  const qc = useQueryClient();
  const { showToast } = useToast();
  const { notifyError } = useErrorNotifier();

  const createPostMutation = useMutation({
    mutationFn: async () => {
      const imageUploadIds = await uploadIdsFor(draft.visualMedia);
      const anonymous = draft.displayIdentity === 'ANONYMOUS';
      return createPost({
        title: draft.title.trim(),
        content: draft.content,
        imageUploadIds,
        ...draft.section,
        useAnonymousAlias: anonymous,
        status: draft.progress,
        mentionUserIds: mentionIdsIn(`${draft.title}\n${draft.content}`),
        ...(anonymous && { anonymousAlias: draft.anonymousAlias.trim() || '匿名同学' }),
      });
    },
    onSuccess: (createdPost) => {
      qc.setQueryData(['posts', createdPost.id], createdPost);
      // Pages are numbered server-side; refetching is simpler and exact.
      qc.invalidateQueries({ predicate: isTimeline });
      showToast({
        title: createdPost.status === 'PUBLISHED' ? '发布成功' : '已提交审核，通过后会公开显示',
        type: 'success',
      });
      revokeVisualMediaObjectUrls(draft.visualMedia);
      exitCreatePostModal();
    },
    onError: (err) => {
      notifyError(err, '发布失败');
    },
  });

  const editPostMutation = useMutation({
    mutationFn: async () => {
      if (!editing) throw new Error('没有正在编辑的帖子');
      const text = `${draft.title}\n${draft.content}`;
      // Send only what changed: untouched images must not be re-listed (the
      // list replaces the post's images), and untouched text keeps its format.
      const imagesChanged =
        draft.visualMedia.map((media) => media.uploadId ?? media.url).join('\n') !==
        editing.visualMedia.map((media) => media.uploadId ?? media.url).join('\n');
      return editPost(editing.id, {
        title: draft.title.trim(),
        ...(draft.content !== (editing.content ?? '') && { content: draft.content }),
        ...(imagesChanged && { imageUploadIds: await uploadIdsFor(draft.visualMedia) }),
        ...(draft.progress !== editing.progress && { status: draft.progress }),
        mentionUserIds: mentionIdsIn(text, editing.mentions),
      });
    },
    onSuccess: (edited) => {
      qc.setQueryData(['posts', edited.id], edited);
      showToast({
        title: edited.status === 'PUBLISHED' ? '已保存修改' : '修改已提交审核，通过后会公开显示',
        type: 'success',
      });
      revokeVisualMediaObjectUrls(draft.visualMedia.filter((media) => !media.uploadId));
      exitCreatePostModal();
    },
    onError: (err) => {
      notifyError(err, '保存失败');
    },
  });

  return { createPostMutation, editPostMutation };
}
