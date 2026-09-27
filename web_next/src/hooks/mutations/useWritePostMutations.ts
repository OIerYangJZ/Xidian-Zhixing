import { InfiniteData, useMutation, useQueryClient } from '@tanstack/react-query';
import { chunk } from 'lodash';
import { useSession } from '@/lib/backend/session';
import { GetVisualMedia, GetPost, PostIds } from '@/types/definitions';
import type { DisplayIdentity } from '@prisma/client';
import { POSTS_PER_PAGE } from '@/constants';
import { revokeVisualMediaObjectUrls } from '@/lib/revokeVisualMediaObjectUrls';
import { useToast } from '../useToast';
import { useErrorNotifier } from '../useErrorNotifier';

async function readPostResponse(response: Response) {
  if (!response.ok) {
    const payload = (await response.json().catch(() => null)) as { error?: string } | null;
    throw new Error(payload?.error || response.statusText);
  }
  return (await response.json()) as GetPost;
}

export function useWritePostMutations({
  content,
  visualMedia,
  displayIdentity,
  exitCreatePostModal,
}: {
  content: string;
  visualMedia: GetVisualMedia[];
  displayIdentity: DisplayIdentity;
  exitCreatePostModal: () => void;
}) {
  const qc = useQueryClient();
  const { data: session } = useSession();
  const queryKey = ['users', session?.user?.id, 'posts'];
  const { showToast } = useToast();
  const { notifyError } = useErrorNotifier();

  const generateFormData = async (): Promise<FormData> => {
    const formData = new FormData();
    if (content) formData.append('content', content);
    formData.append('displayIdentity', displayIdentity);

    const visualMediaFilesPromises = visualMedia.map(async ({ url }) => {
      if (url.startsWith('blob:')) {
        // If the url is a blob, fetch the blob and append it to the formData
        const file = await fetch(url).then((r) => r.blob());
        formData.append('files', file, 'upload');
      } else {
        // If the url is a link, just append it to the formData
        formData.append('files', url);
      }
    });
    await Promise.all(visualMediaFilesPromises);

    return formData;
  };

  const createPostMutation = useMutation({
    mutationFn: async () => {
      const res = await fetch(`/api/posts`, {
        method: 'POST',
        body: await generateFormData(),
      });

      return readPostResponse(res);
    },
    onSuccess: (createdPost) => {
      // Create a query for the created post
      qc.setQueryData(['posts', createdPost.id], createdPost);

      if (createdPost.status === 'PUBLISHED')
        qc.setQueriesData<InfiniteData<PostIds>>({ queryKey }, (oldData) => {
          if (!oldData) return oldData;

          // Flatten the old pages first then prepend the newly created post
          const newPosts = [{ id: createdPost.id, commentsShown: false }, ...(oldData?.pages ?? []).flat()];

          // Chunk the `newPosts` depending on the number of posts per page
          const newPages = chunk(newPosts, POSTS_PER_PAGE);

          const newPageParams = [
            // The first `pageParam` is undefined as the initial page does not use a `pageParam`
            undefined,
            // Create the new `pageParams`, it must contain the id of each page's (except last page's) last post
            ...newPages.slice(0, -1).map((page) => page.at(-1)?.id),
          ];

          return {
            pages: newPages,
            pageParams: newPageParams,
          };
        });
      showToast({
        title: createdPost.status === 'PUBLISHED' ? '发布成功' : '已提交审核，通过后会公开显示',
        type: 'success',
      });
      revokeVisualMediaObjectUrls(visualMedia);
      exitCreatePostModal();
    },
    onError: (err) => {
      notifyError(err, 'Error Creating Post');
    },
  });

  const updatePostMutation = useMutation({
    mutationFn: async ({ postId }: { postId: string }) => {
      const res = await fetch(`/api/posts/${postId}`, {
        method: 'PATCH',
        body: await generateFormData(),
      });

      return readPostResponse(res);
    },
    onSuccess: (updatedPost) => {
      // Update the query for the updated post
      qc.setQueryData(['posts', updatedPost.id], updatedPost);

      // Update the inifinite query of `PostIds` TODO: There might be no need for `setQueriesData`
      qc.setQueriesData<InfiniteData<PostIds>>({ queryKey }, (oldData) => {
        if (!oldData) return oldData;

        // Flatten the old pages first
        const oldPosts = oldData.pages.flat();
        const index = oldPosts.findIndex((post) => post.id === updatedPost.id);
        const newPosts =
          updatedPost.status === 'PUBLISHED'
            ? index < 0
              ? oldPosts
              : oldPosts.map((post) =>
                  post.id === updatedPost.id ? { id: updatedPost.id, commentsShown: false } : post,
                )
            : oldPosts.filter((post) => post.id !== updatedPost.id);

        return {
          pages: chunk(newPosts, POSTS_PER_PAGE),
          pageParams: oldData.pageParams,
        };
      });
      showToast({
        title: updatedPost.status === 'PUBLISHED' ? '动态已更新' : '已提交审核，通过后会公开显示',
        type: 'success',
      });
      revokeVisualMediaObjectUrls(visualMedia);
      exitCreatePostModal();
    },
    onError: (err) => {
      notifyError(err, 'Error Creating Post');
    },
  });

  return { createPostMutation, updatePostMutation };
}
