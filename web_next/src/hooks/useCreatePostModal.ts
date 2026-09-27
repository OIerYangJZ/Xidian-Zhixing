import { useCreatePostModalContextApi } from '@/contexts/CreatePostModalContext';
import type { GetPost } from '@/types/definitions';

export function useCreatePostModal() {
  const { setShown, setShouldOpenFileInputOnMount, setEditingPost } = useCreatePostModalContextApi();

  const launchCreatePost = ({ shouldOpenFileInputOnMount = false }: { shouldOpenFileInputOnMount?: boolean }) => {
    setEditingPost(null);
    setShouldOpenFileInputOnMount(shouldOpenFileInputOnMount);
    setShown(true);
  };

  const launchEditPost = (post: GetPost) => {
    setEditingPost(post);
    setShouldOpenFileInputOnMount(false);
    setShown(true);
  };

  const exitCreatePostModal = () => {
    setShown(false);
  };

  return { launchCreatePost, launchEditPost, exitCreatePostModal };
}
