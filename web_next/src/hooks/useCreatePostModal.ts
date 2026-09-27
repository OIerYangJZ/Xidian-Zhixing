import { useCreatePostModalContextApi } from '@/contexts/CreatePostModalContext';

export function useCreatePostModal() {
  const { setShown, setShouldOpenFileInputOnMount } = useCreatePostModalContextApi();

  const launchCreatePost = ({ shouldOpenFileInputOnMount = false }: { shouldOpenFileInputOnMount?: boolean }) => {
    setShouldOpenFileInputOnMount(shouldOpenFileInputOnMount);
    setShown(true);
  };

  const exitCreatePostModal = () => {
    setShown(false);
  };

  return { launchCreatePost, exitCreatePostModal };
}
