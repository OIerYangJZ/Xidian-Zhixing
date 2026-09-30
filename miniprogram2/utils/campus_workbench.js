import { baseUrl } from '../config/env';

export const DEFAULT_SHORTCUTS = ['classtable', 'exam', 'score', 'electricity', 'schoolnet', 'library', 'map', 'repair'];
export const MAX_SHORTCUTS = 8;
export const CAMPUS_GROUPS = [
  { id: 'all', name: '全部' }, { id: 'study', name: '学习' },
  { id: 'life', name: '生活' }, { id: 'affairs', name: '办事' }, { id: 'tools', name: '工具' }
];
const ICONS = {
  classtable: 'calendar-days', exam: 'list', experiment: 'flask-conical', score: 'chart',
  'empty-classroom': 'campus', attendance: 'check', sport: 'person', electricity: 'brand',
  'dorm-water': 'droplets', library: 'book-open', 'school-card': 'credit-card', schoolnet: 'wifi',
  map: 'campus', 'building-map': 'campus', places: 'campus', payment: 'display',
  repair: 'wrench', 'space-reservation': 'calendar-days', leave: 'check', 'campus-email': 'mail'
};
const GROUP_NAMES = { study: '学习', life: '生活', affairs: '办事', tools: '工具', quick: '工具' };
const ICON_KEYS = { calendar:'calendar-days', flask:'flask-conical', chart:'chart', building:'campus', check:'check', activity:'person', bolt:'brand', drop:'droplets', book:'book-open', card:'credit-card', network:'wifi', map:'campus', mail:'mail', tool:'wrench', repair:'wrench', star:'group' };

export const schoolClock = (timestamp = Date.now()) => {
  const date = new Date(timestamp + 8 * 60 * 60 * 1000);
  return { date: date.toISOString().slice(0, 10), minutes: date.getUTCHours() * 60 + date.getUTCMinutes(), time: date.toISOString().slice(11, 16) };
};

export const canOpenCampusUrl = (value) => {
  const origin = /^([a-zA-Z][a-zA-Z0-9+.-]*):\/\/([^/?#]+)/.exec(String(value || '').trim());
  if (!origin || origin[2].includes('@')) return false;
  const host = origin[2].split(':')[0].toLowerCase();
  const self = /^([a-zA-Z][a-zA-Z0-9+.-]*):\/\/([^/?#]+)/.exec(baseUrl);
  if (self && origin[1].toLowerCase() === self[1].toLowerCase() && host === self[2].split(':')[0].toLowerCase()) return true;
  return origin[1].toLowerCase() === 'https' && (host === 'xidian.edu.cn' || host.endsWith('.xidian.edu.cn'));
};

export const prepareCampusServices = (rows) => {
  if (!Array.isArray(rows)) throw new Error('校园服务响应格式无效');
  return rows
  .filter(row => row && row.id && row.groupId !== 'account' && row.enabled !== false)
  .map(row => {
    const actions = (Array.isArray(row.actions) ? row.actions : []).filter(action => action && action.type !== 'notice');
    const isSchedule = row.kind === 'schedule' || !!row.calendarSource;
    const isMap = ['map', 'campus-map', 'building-map'].includes(row.slug) || actions.some(action => action.type === 'map');
    const targets = actions.filter(action => ['external', 'page'].includes(action.type) && (action.url || action.path));
    const native = isSchedule || isMap;
    const usable = native || targets.some(action => action.type === 'page' || canOpenCampusUrl(action.url));
    return {
      ...row, actions, targets, isSchedule, isMap, usable,
      groupId: GROUP_NAMES[row.groupId] ? (row.groupId === 'quick' ? 'tools' : row.groupId) : 'tools',
      groupLabel: GROUP_NAMES[row.groupId] || '工具',
      icon: ICONS[row.slug] || ICON_KEYS[row.iconKey] || 'info',
      tone: row.groupId === 'study' ? 'study' : row.groupId === 'life' ? 'life' : row.groupId === 'affairs' ? 'affairs' : 'tools',
      modeLabel: native ? (isSchedule ? '日程' : '地图') : targets.some(action=>action.type==='page') ? '站内功能' : usable ? '学校服务' : targets.length ? '浏览器打开' : '暂未接入'
    };
  });
};

export const filterCampusServices = (services, group = 'all', keyword = '') => {
  const search = String(keyword).trim().toLowerCase();
  return services.filter(service => (group === 'all' || service.groupId === group)
    && (!search || `${service.name} ${service.groupLabel} ${service.summary || ''} ${service.description || ''}`.toLowerCase().includes(search)));
};

export const readCampusPreferences = (stored, services) => {
  const available = new Set(services.filter(service => service.usable).map(service => service.id));
  const hasSaved = stored && Array.isArray(stored.shortcutIds);
  const defaults = DEFAULT_SHORTCUTS.map(slug => services.find(service => service.slug === slug && service.usable)?.id).filter(Boolean);
  const shortcutIds = Array.from(new Set(hasSaved ? stored.shortcutIds : defaults)).filter(id => available.has(id)).slice(0, MAX_SHORTCUTS);
  return { shortcutIds, showSchedule: !stored || stored.showSchedule !== false, compact: stored?.compact === true };
};

const timeMinutes = (value) => {
  const match = /^(\d{1,2}):(\d{2})$/.exec(String(value || ''));
  return match && Number(match[1]) < 24 && Number(match[2]) < 60 ? Number(match[1]) * 60 + Number(match[2]) : null;
};

export const buildCampusDay = (items = [], date = '', clock = schoolClock()) => {
  const rows = items.map(item => {
    const start = timeMinutes(item.startTime);
    const end = timeMinutes(item.endTime);
    const current = date === clock.date && start !== null && end !== null && clock.minutes >= start && clock.minutes < end;
    const ended = date < clock.date || (date === clock.date && end !== null && clock.minutes >= end);
    const tone = item.source === 'examSchedules' ? 'exam' : item.source === 'experimentSchedules' ? 'experiment' : 'course';
    return { ...item, startMinutes: start, endMinutes: end, current, ended, tone, timeRange: item.timeRange || `${item.startTime || ''}-${item.endTime || ''}`, progress: current && end > start ? Math.round((clock.minutes - start) / (end - start) * 100) : 0 };
  }).sort((a, b) => (a.startMinutes ?? 1440) - (b.startMinutes ?? 1440));
  const current = rows.find(item => item.current);
  const upcoming = rows.find(item => !item.ended && item.startMinutes !== null && (date > clock.date || item.startMinutes > clock.minutes));
  const allEnded = rows.length && rows.every(item => item.ended);
  const focus = current || upcoming || (allEnded ? rows[rows.length - 1] : rows[0]) || null;
  let focusLabel = date === clock.date ? '接下来' : '当日安排';
  let countdown = '';
  if (current) { focusLabel = '正在进行'; countdown = `还有 ${current.endMinutes - clock.minutes} 分钟`; }
  else if (upcoming && date === clock.date) { const minutes = upcoming.startMinutes - clock.minutes; countdown = minutes >= 60 ? `${Math.floor(minutes / 60)} 小时 ${minutes % 60} 分钟后` : `${minutes} 分钟后`; }
  else if (allEnded && date === clock.date) focusLabel = '今日安排已结束';
  else if (rows.length && date === clock.date) focusLabel = '今日安排';
  return { rows, focus, focusLabel, countdown, count: rows.length };
};
