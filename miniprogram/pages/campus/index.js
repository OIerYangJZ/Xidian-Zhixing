import { getCalendarSchedules, getCampusServices, getTodaySchedules } from '../../api/campus';
import { sectionTone } from '../../utils/format';
import { getUserInfo } from '../../api/auth';
import { getAnnouncementDailySummary } from '../../api/announcements';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';
import { avatarInitial } from '../../utils/format';
import { openAppTarget } from '../../utils/navigation';

// Start times of the five two-period blocks, as on web (1–2 … 9–10).
const SLOT_STARTS = ['08:30', '10:25', '14:00', '15:55', '19:00'];
const WEEKDAYS = ['一', '二', '三', '四', '五', '六', '日'];
const pad = (n) => String(n).padStart(2, '0');
const isoDate = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const mondayOf = (d) => {
  const day = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  day.setDate(day.getDate() - ((day.getDay() + 6) % 7));
  return day;
};

// Which block an item sits in: its section ("3-4" → 1) when given,
// otherwise the last block starting at or before it.
const slotOf = (item) => {
  const match = /^\s*(\d+)/.exec(String(item.section || ''));
  if (match) return Math.min(4, Math.max(0, Math.floor((Number(match[1]) - 1) / 2)));
  let slot = 0;
  SLOT_STARTS.forEach((start, i) => {
    if (String(item.startTime || '') >= start) slot = i;
  });
  return slot;
};

// Icon, tone and the ↗ mark of a service entry.
const ICONS = [
  [/map|地图|楼宇|定位/, 'map'], [/exam|考试/, 'exam'], [/class|课表/, 'calendar'],
  [/library|图书/, 'book'], [/water|水/, 'cloud'], [/实验|lab/, 'flask'], [/net|网/, 'wifi'],
  [/mail|邮/, 'mail'], [/card|卡/, 'idcard'], [/room|教室/, 'building'], [/成绩|grade/, 'list'],
  [/考勤/, 'clock'], [/电费/, 'key'], [/指南|guide/, 'doc']
];
const decorateService = (service) => {
  const text = `${service.slug || ''} ${service.name || ''}`;
  const found = ICONS.find(([re]) => re.test(text));
  const action = Array.isArray(service.actions) ? service.actions[0] : null;
  return {
    ...service,
    icon: found ? found[1] : 'grid',
    tone: sectionTone(service.slug || service.name),
    external: Boolean(action && action.type === 'external')
  };
};

const shortTitle = (title) => String(title || '').replace(/^示例[:：]/, '').slice(0, 4);

Page({
  data: {
    weekStart: '',
    weekLabel: '',
    isThisWeek: true,
    weekDays: [],
    timetable: [],
    timetableError: '',
    exams: [],
    navTop: 0,
    navHeight: 48,
    drawerOpen: false,
    services: [],
    groupedServices: [],
    todaySchedules: [],
    todayScheduleDate: '',
    lastScheduleUpdatedAt: 0,
    userInfo: null,
    errorMessage: '',
    touchStartX: 0,
    touchStartY: 0
  },

  onLoad() {
    this.initCustomNav();
    if (!requireLoginPage()) return;
    this._weekStart = mondayOf(new Date());
    this.loadData();
    this.loadWeek();
    this.loadExams();
  },

  onShow() {
    applyThemeAndLanguage(this);
    this.initCustomNav();
    const updatedAt = Number(wx.getStorageSync('campusScheduleUpdatedAt') || 0);
    if (updatedAt && updatedAt !== this.data.lastScheduleUpdatedAt) {
      this.setData({ lastScheduleUpdatedAt: updatedAt });
      this.loadData();
    }
  },

  initCustomNav() {
    const app = getApp();
    this.setData({
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32
    });
  },

  // Today's announcements in one line; the card works without it.
  async loadAnnouncementSummary() {
    try {
      const daily = await getAnnouncementDailySummary();
      this.setData({ announcementSummary: daily.summary });
    } catch (error) {}
  },

  openAnnouncements() {
    wx.navigateTo({ url: '/pages/campus/announcements/index' });
  },

  async loadData() {
    this.setData({ errorMessage: '' });
    this.loadAnnouncementSummary();
    try {
      const [servicesResponse, todaySchedulesResponse] = await Promise.all([
        getCampusServices(),
        getTodaySchedules()
      ]);
      const services = servicesResponse.data;
      const scheduleData = todaySchedulesResponse.data;
      const usableServices = services.filter((service) => {
        const actions = Array.isArray(service.actions) ? service.actions : [];
        return service.groupId !== 'account' && actions.some((action) => action && action.type !== 'notice');
      });
      const groups = [];
      usableServices.forEach((raw) => {
        const service = decorateService(raw);
        let group = groups.find((item) => item.id === service.groupId);
        if (!group) {
          group = { id: service.groupId, name: service.groupName, items: [] };
          groups.push(group);
        }
        group.items.push(service);
      });
      this.setData({
        services: usableServices,
        groupedServices: groups,
        todaySchedules: scheduleData.items,
        todayScheduleDate: scheduleData.date
      });
    } catch (error) {
      this.setData({
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '校园服务加载失败，请重试'
      });
    }
  },

  async loadWeek() {
    const start = this._weekStart || mondayOf(new Date());
    const end = new Date(start);
    end.setDate(end.getDate() + 6);
    this.setData({
      timetableError: '',
      isThisWeek: isoDate(start) === isoDate(mondayOf(new Date())),
      weekLabel: `${pad(start.getMonth() + 1)}-${pad(start.getDate())} 至 ${pad(end.getMonth() + 1)}-${pad(end.getDate())}`
    });
    try {
      const response = await getCalendarSchedules({ startDate: isoDate(start), days: 7, source: 'academic' });
      const days = response.data.days;
      const weekendUsed = days.slice(5).some((day) => (day.items || []).length);
      const shown = weekendUsed ? days : days.slice(0, 5);
      this.setData({
        weekDays: days.map((day, i) => ({
          label: WEEKDAYS[i],
          day: String(day.date || '').slice(8, 10),
          isToday: Boolean(day.isToday),
          dots: Math.min(3, (day.items || []).length)
        })),
        timetable: SLOT_STARTS.map((startTime, slot) => ({
          label: `${slot * 2 + 1}–${slot * 2 + 2}`,
          cells: shown.map((day) => {
            const items = (day.items || []).filter((item) => slotOf(item) === slot);
            const item = items[0];
            return item
              ? { key: `${day.date}-${slot}`, title: shortTitle(item.title), tone: item.source === 'examSchedules' ? 0 : sectionTone(item.title), source: item.source, today: Boolean(day.isToday) }
              : { key: `${day.date}-${slot}`, title: '', today: Boolean(day.isToday) };
          })
        }))
      });
    } catch (error) {
      this.setData({ timetableError: '课表加载失败，点击重试' });
    }
  },

  shiftWeek(event) {
    const delta = Number(event.currentTarget.dataset.delta || 0);
    const start = new Date(this._weekStart || mondayOf(new Date()));
    start.setDate(start.getDate() + delta * 7);
    this._weekStart = start;
    this.loadWeek();
  },

  thisWeek() {
    this._weekStart = mondayOf(new Date());
    this.loadWeek();
  },

  async loadExams() {
    const today = new Date();
    const day0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    try {
      const response = await getCalendarSchedules({ startDate: isoDate(today), days: 31, source: 'examSchedules' });
      const exams = [];
      response.data.days.forEach((day) => (day.items || []).forEach((item) => {
        const date = new Date(`${day.date}T00:00:00`);
        const inDays = Math.round((date - day0) / 86400000);
        exams.push({
          id: item.id,
          source: item.source,
          day: pad(date.getDate()),
          month: `${date.getMonth() + 1} 月`,
          title: item.title,
          meta: [item.timeRange || item.startTime, item.location, item.seatNo ? `座位 ${item.seatNo}` : '']
            .filter(Boolean).join(' · '),
          countdown: inDays === 0 ? '今天' : `还有 ${inDays} 天`,
          soon: inDays <= 14
        });
      }));
      this.setData({ exams });
    } catch (error) {
      this.setData({ exams: [] });
    }
  },

  async loadUserInfo() {
    try {
      const response = await getUserInfo();
      const user = response.data || {};
      this.setData({
        userInfo: {
          ...user,
          avatarInitial: avatarInitial(user.nickname || user.alias || user.email)
        }
      });
    } catch (error) {
      this.setData({
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '用户信息加载失败，请重试'
      });
    }
  },

  retryLoad() {
    this.loadUserInfo();
    this.loadData();
  },

  openDrawer() {
    this.setData({ drawerOpen: true });
  },

  closeDrawer() {
    this.setData({ drawerOpen: false });
  },

  openService(event) {
    const service = this.data.services.find((item) => item.id === event.currentTarget.dataset.id);
    if (!service) return;
    const action = Array.isArray(service.actions) ? service.actions[0] : null;
    if (service.slug === 'map' || service.slug === 'campus-map' || (action && action.type === 'map')) {
      wx.navigateTo({ url: '/pages/campus/map/index' });
      return;
    }
    if (service.groupId === 'quick' && action && action.type === 'external') {
      if (!openAppTarget(action || service)) {
        wx.showToast({ title: '入口不可用', icon: 'none' });
      }
      return;
    }
    if (service.kind === 'external' && action && action.type === 'external') {
      if (!openAppTarget(action || service)) {
        wx.showToast({ title: '入口不可用', icon: 'none' });
      }
      return;
    }
    wx.navigateTo({ url: `/pages/campus/service-detail/index?id=${service.id}&name=${encodeURIComponent(service.name)}` });
  },

  openIdsLogin() {
    wx.navigateTo({ url: '/pages/campus/auth-center/index?system=schoolnet' });
  },

  openQuickLink(event) {
    const service = this.data.services.find((item) => item.id === event.currentTarget.dataset.id);
    if (!service) return;
    const action = Array.isArray(service.actions) ? service.actions[0] : null;
    if (!openAppTarget(action || service)) {
      wx.showToast({ title: '入口不可用', icon: 'none' });
    }
  },

  openScheduleService(event) {
    const source = event.currentTarget.dataset.source || 'courseSchedules';
    const sourceToSlug = {
      courseSchedules: 'classtable',
      examSchedules: 'exam',
      experimentSchedules: 'experiment'
    };
    const slug = sourceToSlug[source] || 'classtable';
    const service = this.data.services.find((item) => item.slug === slug);
    if (!service) return;
    wx.navigateTo({ url: `/pages/campus/service-detail/index?id=${service.id}&name=${encodeURIComponent(service.name)}` });
  },

  onTouchStart(event) {
    const touch = event.touches && event.touches[0];
    if (!touch) return;
    this.setData({ touchStartX: touch.clientX, touchStartY: touch.clientY });
  },

  onTouchEnd(event) {
    const touch = event.changedTouches && event.changedTouches[0];
    if (!touch) return;
    const deltaX = touch.clientX - this.data.touchStartX;
    const deltaY = Math.abs(touch.clientY - this.data.touchStartY);
    if (this.data.touchStartX < 24 && deltaX > 70 && deltaY < 50) this.openDrawer();
  }
});
