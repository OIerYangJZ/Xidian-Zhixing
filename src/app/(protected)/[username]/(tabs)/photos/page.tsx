import { GetVisualMedia } from '@/types/definitions';
import prisma from '@/lib/prisma/prisma';
import { fileNameToUrl } from '@/lib/s3/fileNameToUrl';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { getServerUser } from '@/lib/getServerUser';
import { getProfile } from '../../getProfile';
import { Gallery } from './Gallery';

export async function generateMetadata(props: { params: Promise<{ username: string }> }) {
  const params = await props.params;
  const profile = await getProfile(params.username);
  const title = (await getInterfaceLanguage()) === 'en' ? 'Photos' : '照片';
  return { title: `${title} | ${profile?.name || ((await getInterfaceLanguage()) === 'en' ? 'Zhixing' : '西电知行')}` };
}

async function getVisualMedia(username: string) {
  const profile = await getProfile(username);
  if (!profile) return [];

  const [viewer] = await getServerUser();

  const media = await prisma.visualMedia.findMany({
    where: {
      userId: profile.id,
      ...(viewer?.id === profile.id
        ? {}
        : {
            post: {
              is: {
                displayIdentity: 'USER' as const,
                status: 'PUBLISHED' as const,
                moderationCases: { none: { status: 'OPEN' as const } },
              },
            },
          }),
    },
    orderBy: { id: 'desc' },
  });

  return media.map(({ type, fileName }) => ({ type, url: fileNameToUrl(fileName)! })) as GetVisualMedia[];
}

export default async function Page(props: { params: Promise<{ username: string }> }) {
  const params = await props.params;
  const visualMedia = await getVisualMedia(params.username);
  return <Gallery visualMedia={visualMedia} />;
}
