import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { campusQuickLinks, getCampusServices } from '@/lib/campus/catalog';
import { CampusDirectory } from './CampusDirectory';

export const metadata = { title: '校园 | 西电知行' };

export default async function CampusPage() {
  const [user] = await getServerUser();
  const identityCount = user?.id ? await prisma.institutionIdentity.count({ where: { userId: user.id } }) : 0;
  const services = getCampusServices(identityCount > 0);
  const campusGroups = Array.from(new Set(services.map((service) => service.groupName))).map((title) => ({
    title,
    services: services.filter((service) => service.groupName === title),
  }));

  return <CampusDirectory quickLinks={campusQuickLinks} groups={campusGroups} />;
}
