import type { ApiCampusService } from '@/lib/backend/endpoints';
import { campusServiceHref } from '@/lib/profileHref';

export type CampusService = {
  id: string;
  slug: string;
  name: string;
  groupId: string;
  groupName: string;
  kind: string;
  iconKey: string;
  authType: 'campus-sso' | 'schoolnet' | 'official-api' | 'public';
  authReady: boolean;
  status: 'available' | 'pending';
  requiredAccess: readonly string[];
  features: readonly string[];
  dataFields: readonly string[];
  calendarSource: 'course' | 'exam' | 'experiment' | null;
  emptyText: string;
  mapIds: readonly string[];
  actions: readonly string[];
  path: string;
  enabled: boolean;
  sortOrder: number;
};

/** Services that talk to a school system from this site, rather than linking out. */
export const AUTH_PANEL_SLUGS = new Set(['network-usage', 'online-devices', 'dorm-water']);

/** Backend catalogue row → the shape the directory renders. */
export function toCampusService(service: ApiCampusService): CampusService {
  const pending = !service.status || service.status.includes('待');
  return {
    ...service,
    authType: (['campus-sso', 'schoolnet', 'official-api', 'public'].includes(service.authType)
      ? service.authType
      : 'public') as CampusService['authType'],
    status: pending ? 'pending' : 'available',
    calendarSource: (['course', 'exam', 'experiment'].includes(service.calendarSource)
      ? service.calendarSource
      : null) as CampusService['calendarSource'],
    actions: service.actions.map((action) => action.label),
    path: campusServiceHref(service.slug || service.id),
  };
}

export const campusQuickLinks = [
  {
    id: 'ehall',
    name: '一站式服务大厅',
    url: 'https://ehall.xidian.edu.cn/new/index.html',
    description: '打开学校一站式服务大厅。',
  },
  { id: 'schoolnet', name: '校园网自服务', url: 'https://zfw.xidian.edu.cn', description: '打开校园网自服务入口。' },
  {
    id: 'ids',
    name: '统一身份认证',
    url: 'https://ids.xidian.edu.cn/authserver/login',
    description: '打开学校统一身份认证。',
  },
] as const;

export const campusMaps: never[] = [];
