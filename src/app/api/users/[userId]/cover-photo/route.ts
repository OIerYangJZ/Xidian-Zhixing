import { useUpdateProfileAndCoverPhoto } from '@/hooks/useUpdateProfileAndCoverPhoto';

export async function POST(request: Request, props: { params: Promise<{ userId: string }> }) {
  const params = await props.params;
  return useUpdateProfileAndCoverPhoto({
    request,
    toUpdate: 'coverPhoto',
    userIdParam: params.userId,
  });
}
