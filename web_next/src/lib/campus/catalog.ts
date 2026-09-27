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

const serviceDefinitions = [
  {
    slug: 'network-usage',
    name: '校园网用量',
    groupId: 'life',
    groupName: '校园生活',
    kind: 'network',
    iconKey: 'network',
    authType: 'schoolnet',
    dataFields: ['used', 'remaining', 'period'],
    calendarSource: null,
  },
  {
    slug: 'online-devices',
    name: '在线设备',
    groupId: 'life',
    groupName: '校园生活',
    kind: 'network',
    iconKey: 'device',
    authType: 'schoolnet',
    dataFields: ['deviceName', 'ipAddress', 'connectedAt'],
    calendarSource: null,
  },
] as const;

export function getCampusServices(authReady: boolean): CampusService[] {
  return serviceDefinitions.map((service, index) => {
    return {
      ...service,
      id: `campus-${service.slug}`,
      authReady,
      status: 'available' as const,
      requiredAccess: ['本人校园网账号、密码和图形验证码'],
      features: ['本人授权登录'],
      emptyText: '使用学校校园网自服务登录，查询本人流量摘要与当前在线设备。密码只在本次请求中使用。',
      mapIds: [],
      actions: ['登录并查询'],
      path: `/campus/${service.slug}`,
      enabled: true,
      sortOrder: index,
    };
  });
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
