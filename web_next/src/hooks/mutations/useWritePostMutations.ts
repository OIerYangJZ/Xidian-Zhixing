import { Query, useMutation, useQueryClient } from '@tanstack/react-query';
import { GetVisualMedia, DisplayIdentity } from '@/types/definitions';
import { createPost, uploadImage } from '@/lib/backend/endpoints';
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
}

/** Timelines a new post can appear in: the feed and the author's profile. */
const isTimeline = (query: Query) => {
  const [head, second, third] = query.queryKey;
  return (head === 'posts' && second === 'feed') || third === 'posts';
};

/**
 * Creating is the only write: the backend does not edit a post's text or
 * images after publishing (PATCH only changes its 进行中/已解决 status).
 */
export function useWritePostMutations({ draft, exitCreatePostModal }: { draft: PostDraft; exitCreatePostModal: () => void }) {
  const qc = useQueryClient();
  const { showToast } = useToast();
  const { notifyError } = useErrorNotifier();

  const createPostMutation = useMutation({
    mutationFn: async () => {
      // Images upload one by one (base64 JSON), then attach by id.
      const imageUploadIds: string[] = [];
      for (const [index, { url }] of draft.visualMedia.entries()) {
        const file = await fetch(url).then((r) => r.blob());
        // eslint-disable-next-line no-await-in-loop
        const upload = await uploadImage(file, `image-${index + 1}`);
        if (upload.status === 'rejected') {
          throw new Error(upload.moderationReason || '有图片未通过审核，请更换后再发布');
        }
        imageUploadIds.push(upload.id);
      }
      const anonymous = draft.displayIdentity === 'ANONYMOUS';
      return createPost({
        title: draft.title.trim(),
        content: draft.content,
        imageUploadIds,
        ...draft.section,
        useAnonymousAlias: anonymous,
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

  return { createPostMutation };
}
