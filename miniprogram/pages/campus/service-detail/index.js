import {
  getCalendarSchedules,
  getCampusServiceDetail
} from '../../../api/campus';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { openAppTarget } from '../../../utils/navigation';

const WEEKDAY_LABELS = ['一', '二', '三', '四', '五', '六', '日'];
const WEEKDAY_NAMES = ['Mon.', 'Tue.', 'Wed.', 'Thu.', 'Fri.', 'Sat.', 'Sun.'];
const SECTION_ROWS = [
  { section: 1, start: '08:30', end: '09:15', period: 'mo' },
  { section: 2, start: '09:20', end: '10:05', period: '' },
  { section: 3, start: '10:25', end: '11:10', period: '' },
  { section: 4, start: '11:15', end: '12:00', period: '' },
  { section: 5, start: '14:00', end: '14:45', period: 'Noon' },
  { section: 6, start: '14:50', end: '15:35', period: '' },
  { section: 7, start: '15:55', end: '16:40', period: '' },
  { section: 8, start: '16:45', end: '17:30', period: '' },
  { section: 9, start: '19:00', end: '19:45', period: 'Super' },
  { section: 10, start: '19:50', end: '20:35', period: '' },
  { section: 11, start: '20:40', end: '21:25', period: '' }
];
const COURSE_COLORS = ['cyan', 'purple', 'indigo', 'pink', 'green', 'blue', 'rose'];

const dateToYmd = (date) => {
  const pad = (value) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
};

const shortDate = (value = '') => {
  const [, month = '', day = ''] = String(value).match(/^\d{4}-(\d{2})-(\d{2})$/) || [];
  return month && day ? `${Number(month)}.${Number(day)}` : value;
};

const mondayOf = (date) => {
  const next = new Date(date);
  const day = next.getDay() === 0 ? 7 : next.getDay();
  next.setDate(next.getDate() - day + 1);
  next.setHours(0, 0, 0, 0);
  return next;
};

const addDays = (date, days) => {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
};

const minutesOf = (value = '') => {
  const [hour, minute] = String(value || '').split(':').map((item) => Number(item));
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return 0;
  return hour * 60 + minute;
};

const sectionForTime = (value = '') => {
  const target = minutesOf(value);
  let best = SECTION_ROWS[0].section;
  SECTION_ROWS.forEach((row) => {
    if (target >= minutesOf(row.start)) best = row.section;
  });
  return best;
};

const isAcademicSource = (source = '') => source === 'courseSchedules' || source === 'examSchedules';

const normalizeCalendarSource = (source = '') => {
  if (isAcademicSource(source)) return 'academic';
  return source || 'academic';
};

const buildCalendarDays = (calendar = {}) => {
  const days = Array.isArray(calendar.days) ? calendar.days : [];
  return days.map((day) => {
    const date = new Date(`${day.date}T00:00:00`);
    const dayIndex = date.getDay() === 0 ? 6 : date.getDay() - 1;
    return {
      ...day,
      label: WEEKDAY_LABELS[dayIndex] || '',
      shortDate: shortDate(day.date),
      items: Array.isArray(day.items) ? day.items : []
    };
  });
};

const buildWeekDots = (days = []) => {
  const activeSlots = new Set();
  days.forEach((day, dayIndex) => {
    (day.items || []).forEach((item) => {
      const rowIndex = Math.max(0, sectionForTime(item.startTime) - 1);
      activeSlots.add(`${dayIndex}-${Math.min(rowIndex, 4)}`);
    });
  });
  return Array.from({ length: 35 }).map((_, index) => {
    const dayIndex = index % 7;
    const rowIndex = Math.floor(index / 7);
    return { active: activeSlots.has(`${dayIndex}-${rowIndex}`) };
  });
};

const buildWeekOptions = (selectedStartDate = '', days = []) => {
  const selected = selectedStartDate ? new Date(`${selectedStartDate}T00:00:00`) : mondayOf(new Date());
  const currentStart = dateToYmd(mondayOf(new Date()));
  return Array.from({ length: 17 }).map((_, index) => {
    const offset = index - 8;
    const start = addDays(selected, offset * 7);
    const startDate = dateToYmd(start);
    const endDate = dateToYmd(addDays(start, 6));
    return {
      label: startDate === currentStart ? '本周' : `${shortDate(startDate)}`,
      range: `${shortDate(startDate)}-${shortDate(endDate)}`,
      startDate,
      dots: offset === 0 ? buildWeekDots(days) : Array.from({ length: 35 }).map(() => ({ active: false }))
    };
  });
};

const buildScheduleGrid = (days = []) => {
  const columns = days.map((day, index) => ({
    date: day.date,
    name: WEEKDAY_NAMES[index] || '',
    dayNumber: String(day.date || '').slice(8),
    label: WEEKDAY_LABELS[index] || ''
  }));
  const colorMap = {};
  let colorIndex = 0;
  const blocks = [];
  days.forEach((day, dayIndex) => {
    (day.items || []).forEach((item) => {
      const startSection = sectionForTime(item.startTime);
      const stopSection = Math.max(startSection, sectionForTime(item.endTime));
      const span = Math.max(1, stopSection - startSection + 1);
      const key = `${item.source}-${item.title}`;
      if (!colorMap[key]) {
        colorMap[key] = COURSE_COLORS[colorIndex % COURSE_COLORS.length];
        colorIndex += 1;
      }
      blocks.push({
        ...item,
        color: item.source === 'examSchedules' ? 'rose' : colorMap[key],
        isExam: item.source === 'examSchedules',
        gridColumn: dayIndex + 2,
        gridRow: startSection + 1,
        span,
        locationText: item.location ? `@${item.location}` : '',
        shortTitle: item.source === 'examSchedules' ? `${item.title}考试` : item.title
      });
    });
  });
  return {
    columns,
    rows: SECTION_ROWS,
    blocks
  };
};

const businessActions = (service = {}) => {
  const actions = Array.isArray(service.actions) ? service.actions : [];
  return actions.filter((action) => action && !['calendar', 'notice'].includes(action.type));
};

Page({
  data: {
    id: '',
    name: '',
    service: null,
    actions: [],
    calendar: null,
    calendarDays: [],
    calendarGrid: { columns: [], rows: SECTION_ROWS, blocks: [] },
    weekOptions: [],
    selectedWeekStartDate: '',
    selectedDate: '',
    maps: [],
    loading: true
  },

  onLoad(options) {
    const id = options.id || '';
    const name = decodeURIComponent(options.name || '');
    this.setData({ id, name });
    if (name) wx.setNavigationBarTitle({ title: name });
    this.loadData();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const detailResponse = await getCampusServiceDetail(this.data.id);
      const service = detailResponse.data || detailResponse || {};
      const source = service.calendarSource || '';
      let calendar = null;
      let calendarDays = [];
      if (service.kind === 'schedule' || source) {
        const startDate = this.data.selectedWeekStartDate || '';
        const calendarData = await getCalendarSchedules({
          source: normalizeCalendarSource(source),
          startDate,
          days: 7
        });
        calendar = calendarData.data || calendarData || {};
        calendarDays = buildCalendarDays(calendar);
      }
      const selectedWeekStartDate = (calendar && calendar.startDate) || this.data.selectedWeekStartDate;
      wx.setNavigationBarTitle({ title: service.name || this.data.name || '校园服务' });
      this.setData({
        service,
        actions: businessActions(service),
        name: service.name || this.data.name,
        calendar,
        calendarDays,
        calendarGrid: buildScheduleGrid(calendarDays),
        weekOptions: buildWeekOptions(selectedWeekStartDate, calendarDays),
        selectedWeekStartDate,
        selectedDate: selectedWeekStartDate,
        maps: service.maps || [],
        loading: false
      });
    } catch (error) {
      console.error(error);
      this.setData({ loading: false });
    }
  },

  async reloadCalendar() {
    const service = this.data.service || {};
    const source = service.calendarSource || '';
    if (!(service.kind === 'schedule' || source)) return;
    const calendarData = await getCalendarSchedules({
      source: normalizeCalendarSource(source),
      startDate: this.data.selectedWeekStartDate,
      days: 7
    });
    const calendar = calendarData.data || calendarData || {};
    const calendarDays = buildCalendarDays(calendar);
    const selectedWeekStartDate = calendar.startDate || this.data.selectedWeekStartDate;
    this.setData({
      calendar,
      calendarDays,
      calendarGrid: buildScheduleGrid(calendarDays),
      weekOptions: buildWeekOptions(selectedWeekStartDate, calendarDays),
      selectedWeekStartDate,
      selectedDate: selectedWeekStartDate
    });
  },

  switchWeek(event) {
    const startDate = event.currentTarget.dataset.startDate;
    if (!startDate || startDate === this.data.selectedWeekStartDate) return;
    this.setData({ selectedWeekStartDate: startDate });
    this.reloadCalendar().catch((error) => console.error(error));
  },

  shiftWeek(event) {
    const delta = Number(event.currentTarget.dataset.delta || 0);
    const base = this.data.selectedWeekStartDate
      ? new Date(`${this.data.selectedWeekStartDate}T00:00:00`)
      : mondayOf(new Date());
    const next = dateToYmd(addDays(base, delta * 7));
    this.setData({ selectedWeekStartDate: next });
    this.reloadCalendar().catch((error) => console.error(error));
  },

  pickDate(event) {
    const value = event.detail.value;
    if (!value) return;
    const weekStart = dateToYmd(mondayOf(new Date(`${value}T00:00:00`)));
    this.setData({
      selectedDate: value,
      selectedWeekStartDate: weekStart
    });
    this.reloadCalendar().catch((error) => console.error(error));
  },

  runAction(event) {
    const index = Number(event.currentTarget.dataset.index);
    const action = Array.isArray(this.data.actions) ? this.data.actions[index] : null;
    if (!action) return;

    if (action.type === 'map') {
      wx.navigateTo({ url: '/pages/campus/map/index' });
      return;
    }
    if (!openAppTarget(action)) {
      wx.showToast({ title: '入口不可用', icon: 'none' });
    }
  },

  openMap() {
    wx.navigateTo({ url: '/pages/campus/map/index' });
  }
});
