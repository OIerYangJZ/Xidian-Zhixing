import { useCreatePostModalContextApi } from '@/contexts/CreatePostModalContext';
import { GetVisualMedia } from '@/types/definitions';
import type { DisplayIdentity } from '@prisma/client';

export function useCreatePostModal() {
  const { setShown, setShouldOpenFileInputOnMount, setToEditValues } = useCreatePostModalContextApi();

  const launchCreatePost = ({ shouldOpenFileInputOnMount = false }: { shouldOpenFileInputOnMount?: boolean }) => {
    setToEditValues(null);
    setShouldOpenFileInputOnMount(shouldOpenFileInputOnMount);
    setShown(true);
  };

  const launchEditPost = ({
    initialContent,
    initialVisualMedia,
    initialDisplayIdentity,
    postId,
  }: {
    initialContent: string;
    initialVisualMedia: GetVisualMedia[];
    initialDisplayIdentity: DisplayIdentity;
    postId: number;
  }) => {
    setToEditValues({
      postId,
      initialContent,
      initialVisualMedia,
      initialDisplayIdentity,
    });
    setShown(true);
  };

  const exitCreatePostModal = () => {
    setShown(false);
  };

  return { launchCreatePost, launchEditPost, exitCreatePostModal };
}
