import { GetVisualMedia } from '@/types/definitions';
import prisma from '@/lib/prisma/prisma';
import { fileNameToUrl } from '@/lib/s3/fileNameToUrl';
import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { getProfile } from '../../getProfile';
import { Gallery } from './Gallery';

export async function generateMetadata({ params }: { params: { username: string } }) {
  const profile = await getProfile(params.username);
  const title = getInterfaceLanguage() === 'en' ? 'Photos' : '照片';
  return { title: `${title} | ${profile?.name || (getInterfaceLanguage() === 'en' ? 'Zhixing' : '西电知行')}` };
}

async function getVisualMedia(username: string) {
  const profile = await getProfile(username);
  if (!profile) return [];

  const media = await prisma.visualMedia.findMany({
    where: { userId: profile.id },
    orderBy: { id: 'desc' },
  });

  return media.map(({ type, fileName }) => ({ type, url: fileNameToUrl(fileName)! })) as GetVisualMedia[];
}

export default async function Page({ params }: { params: { username: string } }) {
  const visualMedia = await getVisualMedia(params.username);
  return <Gallery visualMedia={visualMedia} />;
}
