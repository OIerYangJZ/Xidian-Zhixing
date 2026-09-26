import Link from 'next/link';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';
import { campusQuickLinks, getCampusServices } from '@/lib/campus/catalog';
import { PageHeader } from '@/components/ui/PageHeader';

export const metadata = { title: '校园 | 西电知行' };

export default async function CampusPage() {
  const [user] = await getServerUser();
  const identityCount = user?.id ? await prisma.institutionIdentity.count({ where: { userId: user.id } }) : 0;
  const services = getCampusServices(identityCount > 0);
  const campusGroups = Array.from(new Set(services.map((service) => service.groupName))).map((title) => ({
    title,
    services: services.filter((service) => service.groupName === title),
  }));

  return (
    <main>
      <PageHeader title="校园服务" />
      <section className="border-b border-border/80 px-4 py-4 sm:px-5">
        <h2 className="text-sm font-semibold">学校官方入口</h2>
        <div className="mt-3 flex flex-wrap gap-2">
          {campusQuickLinks.map((link) => (
            <a
              key={link.id}
              href={link.url}
              target="_blank"
              rel="noreferrer"
              className="rounded-full border border-border px-3 py-2 text-xs font-medium transition hover:bg-secondary">
              {link.name}
              <span className="ml-1.5 text-muted-foreground" aria-hidden="true">
                ↗
              </span>
            </a>
          ))}
        </div>
      </section>

      <div>
        {campusGroups.map((group) => (
          <section key={group.title} className="border-b border-border/80">
            <div className="px-4 pb-2 pt-5 sm:px-5">
              <h2 className="text-base font-bold">{group.title}</h2>
            </div>
            {group.services.map((service) => (
              <Link
                key={service.slug}
                href={service.path}
                className="group flex items-center gap-3 px-4 py-3.5 transition-colors hover:bg-secondary/50 sm:px-5">
                <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-secondary text-xs font-bold uppercase text-secondary-foreground">
                  {service.iconKey.slice(0, 2)}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-2">
                    <strong className="truncate text-sm font-semibold">{service.name}</strong>
                    <span
                      className={`shrink-0 rounded-full px-2 py-0.5 text-[10px] ${
                        service.enabled
                          ? 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300'
                          : 'bg-secondary text-muted-foreground'
                      }`}>
                      {service.authReady ? '已关联校园身份' : '需先完成校园认证'}
                    </span>
                  </span>
                </span>
                <span
                  className="text-muted-foreground transition group-hover:translate-x-0.5 group-hover:text-foreground"
                  aria-hidden="true">
                  ›
                </span>
              </Link>
            ))}
          </section>
        ))}
      </div>
    </main>
  );
}
