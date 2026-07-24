import {
  getCalendarSchedules,
  getCampusServiceDetail
} from '../../../api/campus';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { openAppTarget } from '../../../utils/navigation';

const WEEKDAY_LABELS = ['一', '二', '三', '四', '五', '六', '日'];
const WEEKDAY_NAMES = ['Mon.', 'Tue.', 'Wed.', 'Thu.', 'Fri.', 'Sat.', 'Sun.'];
const SECTION_ROWS = [
  { section: 1, start: '08:30', end: '09:15' },
  { section: 2, start: '09:20', end: '10:05' },
  { section: 3, start: '10:25', end: '11:10' },
  { section: 4, start: '11:15', end: '12:00' },
  { section: 5, start: '14:00', end: '14:45' },
  { section: 6, start: '14:50', end: '15:35' },
  { section: 7, start: '15:55', end: '16:40' },
  { section: 8, start: '16:45', end: '17:30' },
  { section: 9, start: '19:00', end: '19:45' },
  { section: 10, start: '19:50', end: '20:35' }
];
const COURSE_COLORS = ['cyan', 'purple', 'indigo', 'pink', 'green', 'blue', 'rose'];
const EXAM_LIST_DAYS = 31;
const SCHEDULE_TIME_COL_RPX = 84;
const SCHEDULE_HEADER_RPX = 78;
const SCHEDULE_ROW_RPX = 112;
const SCHEDULE_BOTTOM_RPX = 28;
const SCHEDULE_DAY_WIDTH_PERCENT = 100 / 7;

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

const SCHEDULE_START_MINUTE = minutesOf(SECTION_ROWS[0].start);
const SCHEDULE_END_MINUTE = minutesOf(SECTION_ROWS[SECTION_ROWS.length - 1].end);
const SCHEDULE_TIME_ANCHORS = [
  ...SECTION_ROWS.map((row, index) => ({
    minute: minutesOf(row.start),
    y: SCHEDULE_HEADER_RPX + index * SCHEDULE_ROW_RPX
  })),
  {
    minute: SCHEDULE_END_MINUTE,
    y: SCHEDULE_HEADER_RPX + SECTION_ROWS.length * SCHEDULE_ROW_RPX
  }
];

const sectionForTime = (value = '') => {
  const target = minutesOf(value);
  let best = SECTION_ROWS[0].section;
  SECTION_ROWS.forEach((row) => {
    if (target >= minutesOf(row.start)) best = row.section;
  });
  return best;
};

const fixed = (value) => Number(value).toFixed(3).replace(/\.?0+$/, '');

const scheduleYForTime = (value = '') => {
  const target = minutesOf(value);
  if (target <= SCHEDULE_START_MINUTE) return SCHEDULE_HEADER_RPX;
  for (let index = 0; index < SCHEDULE_TIME_ANCHORS.length - 1; index += 1) {
    const current = SCHEDULE_TIME_ANCHORS[index];
    const next = SCHEDULE_TIME_ANCHORS[index + 1];
    if (target <= next.minute) {
      const ratio = (target - current.minute) / Math.max(1, next.minute - current.minute);
      return current.y + (next.y - current.y) * ratio;
    }
  }
  return SCHEDULE_HEADER_RPX + SECTION_ROWS.length * SCHEDULE_ROW_RPX;
};

const scheduleYForVisualTime = (value = '') => {
  const target = minutesOf(value);
  if (target <= minutesOf(SECTION_ROWS[0].start)) return SCHEDULE_HEADER_RPX;
  for (let index = 0; index < SECTION_ROWS.length; index += 1) {
    const row = SECTION_ROWS[index];
    const rowStart = minutesOf(row.start);
    const rowEnd = minutesOf(row.end);
    const rowTop = SCHEDULE_HEADER_RPX + index * SCHEDULE_ROW_RPX;
    if (target <= rowStart) return rowTop;
    if (target <= rowEnd) {
      return rowTop + ((target - rowStart) / Math.max(1, rowEnd - rowStart)) * SCHEDULE_ROW_RPX;
    }
  }
  return SCHEDULE_HEADER_RPX + SECTION_ROWS.length * SCHEDULE_ROW_RPX;
};

const dayColumnStyle = (dayIndex, insetRpx = 0) => {
  const leftPercent = dayIndex * SCHEDULE_DAY_WIDTH_PERCENT;
  const leftOffset = SCHEDULE_TIME_COL_RPX * (1 - dayIndex / 7) + insetRpx;
  const widthOffset = SCHEDULE_TIME_COL_RPX / 7 + insetRpx * 2;
  return [
    'position: absolute',
    `left: calc(${fixed(leftPercent)}% + ${fixed(leftOffset)}rpx)`,
    `width: calc(${fixed(SCHEDULE_DAY_WIDTH_PERCENT)}% - ${fixed(widthOffset)}rpx)`
  ].join(';');
};

const scheduleRows = () => SECTION_ROWS.map((row) => {
  const topRpx = scheduleYForTime(row.start);
  const heightRpx = SCHEDULE_ROW_RPX;
  return {
    ...row,
    isInnerLine: row.section % 2 === 0,
    topRpx: fixed(topRpx),
    heightRpx: fixed(heightRpx)
  };
});

const schedulePeriods = () => Array.from({ length: SECTION_ROWS.length / 2 }).map((_, index) => ({
  section: index + 1,
  gridRow: `${index * 2 + 2} / span 2`
}));

const uniqueLabels = (labels = []) => Array.from(new Set(labels.filter(Boolean)));

const scheduleTimeLabels = () => {
  const groups = Array.from({ length: SECTION_ROWS.length / 2 }).map((_, index) => {
    const rowIndex = index * 2;
    const labels = rowIndex === 0
      ? [SECTION_ROWS[rowIndex].start]
      : [SECTION_ROWS[rowIndex - 1].end, SECTION_ROWS[rowIndex].start];
    const topRpx = SCHEDULE_HEADER_RPX + rowIndex * SCHEDULE_ROW_RPX;
    return {
      labels: uniqueLabels(labels),
      style: `top: ${fixed(topRpx)}rpx;`
    };
  });
  groups.push({
    labels: [SECTION_ROWS[SECTION_ROWS.length - 1].end],
    style: `top: ${fixed(SCHEDULE_HEADER_RPX + SECTION_ROWS.length * SCHEDULE_ROW_RPX)}rpx;`
  });
  return groups;
};

const isAcademicSource = (source = '') => source === 'courseSchedules' || source === 'examSchedules';

const normalizeCalendarSource = (source = '') => {
  if (isAcademicSource(source)) return 'academic';
  return source || 'academic';
};

const isExamService = (service = {}) => service.slug === 'exam' || service.calendarSource === 'examSchedules';

const calendarQueryForService = (service = {}, startDate = '') => {
  if (isExamService(service)) {
    return { source: 'examSchedules', startDate, days: EXAM_LIST_DAYS };
  }
  return { source: normalizeCalendarSource(service.calendarSource || ''), startDate, days: 7 };
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
      fullRange: `${startDate} - ${endDate}`,
      startDate,
      viewId: `week-${startDate}`,
      dots: offset === 0 ? buildWeekDots(days) : Array.from({ length: 35 }).map(() => ({ active: false }))
    };
  });
};

const activeWeekViewId = (startDate = '') => startDate ? `week-${startDate}` : '';

const activeWeekState = (weekOptions = [], selectedStartDate = '') => {
  const index = Math.max(0, weekOptions.findIndex((item) => item.startDate === selectedStartDate));
  const active = weekOptions[index] || weekOptions[0] || {};
  return {
    weekPickerLabels: weekOptions.map((item) => item.fullRange || item.range || item.startDate),
    weekPickerIndex: index,
    selectedWeekText: active.fullRange || active.range || ''
  };
};

const buildScheduleGrid = (days = []) => {
  const columns = days.map((day, index) => ({
    date: day.date,
    name: WEEKDAY_NAMES[index] || '',
    dayNumber: String(day.date || '').slice(8),
    label: WEEKDAY_LABELS[index] || '',
    blockColumnStyle: dayColumnStyle(index, 3)
  }));
  const colorMap = {};
  let colorIndex = 0;
  const blocks = [];
  days.forEach((day, dayIndex) => {
    (day.items || []).forEach((item) => {
      const isExam = item.source === 'examSchedules';
      const key = `${item.source}-${item.title}`;
      if (!colorMap[key]) {
        colorMap[key] = COURSE_COLORS[colorIndex % COURSE_COLORS.length];
        colorIndex += 1;
      }
      const title = String(item.title || '');
      const startSection = sectionForTime(item.startTime);
      const stopSection = Math.max(startSection, sectionForTime(item.endTime));
      const span = Math.max(1, stopSection - startSection + 1);
      const topRpx = isExam ? scheduleYForVisualTime(item.startTime) : 0;
      const heightRpx = isExam
        ? Math.max(
            SCHEDULE_ROW_RPX * 0.72,
            scheduleYForVisualTime(item.endTime) - topRpx
          )
        : 0;
      blocks.push({
        ...item,
        color: isExam ? 'rose' : colorMap[key],
        isExam,
        blockStyle: isExam
          ? `${columns[dayIndex].blockColumnStyle}; top: ${fixed(topRpx)}rpx; height: ${fixed(heightRpx)}rpx;`
          : `grid-column: ${dayIndex + 2}; grid-row: ${startSection + 1} / span ${span};`,
        locationText: item.location ? `@${item.location}` : '',
        shortTitle: item.source === 'examSchedules' && title && !/考试$/.test(title) ? `${title}考试` : title
      });
    });
  });
  return {
    columns,
    rows: scheduleRows(),
    periods: schedulePeriods(),
    timeLabels: scheduleTimeLabels(),
    blocks,
    heightRpx: fixed(SCHEDULE_HEADER_RPX + SECTION_ROWS.length * SCHEDULE_ROW_RPX + SCHEDULE_BOTTOM_RPX)
  };
};

const buildExamItems = (days = []) => {
  const rows = [];
  days.forEach((day) => {
    (day.items || []).forEach((item) => {
      rows.push({
        ...item,
        dateLabel: `${day.shortDate} 周${day.label || day.weekday || ''}`,
        timeLabel: item.timeRange || `${item.startTime || ''}-${item.endTime || ''}`.replace(/^-|-$/g, ''),
        locationText: item.location || '',
        seatText: item.seatNo || item.section || ''
      });
    });
  });
  rows.sort((left, right) => `${left.date} ${left.startTime} ${left.id}`.localeCompare(`${right.date} ${right.startTime} ${right.id}`));
  return rows;
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
    calendarGrid: { columns: [], rows: scheduleRows(), periods: schedulePeriods(), timeLabels: scheduleTimeLabels(), blocks: [], heightRpx: 0 },
    examItems: [],
    isExamList: false,
    weekOptions: [],
    weekPickerLabels: [],
    weekPickerIndex: 0,
    selectedWeekText: '',
    weekScrollIntoView: '',
    selectedWeekStartDate: '',
    selectedDate: '',
    maps: [],
    navTop: 44,
    navHeight: 32,
    loading: true,
    errorMessage: ''
  },

  onLoad(options) {
    const id = options.id || '';
    const name = decodeURIComponent(options.name || '');
    const app = getApp();
    this.setData({
      id,
      name,
      navTop: (app.globalData && app.globalData.navTop) || 44,
      navHeight: (app.globalData && app.globalData.navHeight) || 32
    });
    this.loadData();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  async loadData() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const detailResponse = await getCampusServiceDetail(this.data.id);
      const service = detailResponse.data || detailResponse || {};
      const source = service.calendarSource || '';
      const isExamList = isExamService(service);
      let calendar = null;
      let calendarDays = [];
      if (service.kind === 'schedule' || source) {
        const startDate = this.data.selectedWeekStartDate || '';
        const calendarData = await getCalendarSchedules(calendarQueryForService(service, startDate));
        calendar = calendarData.data || calendarData || {};
        calendarDays = buildCalendarDays(calendar);
      }
      const selectedWeekStartDate = (calendar && calendar.startDate) || this.data.selectedWeekStartDate;
      const weekOptions = isExamList ? [] : buildWeekOptions(selectedWeekStartDate, calendarDays);
      this.setData({
        service,
        actions: businessActions(service),
        name: service.name || this.data.name,
        calendar,
        calendarDays,
        calendarGrid: buildScheduleGrid(calendarDays),
        examItems: buildExamItems(calendarDays),
        isExamList,
        weekOptions,
        ...activeWeekState(weekOptions, selectedWeekStartDate),
        weekScrollIntoView: activeWeekViewId(selectedWeekStartDate),
        selectedWeekStartDate,
        selectedDate: selectedWeekStartDate,
        maps: service.maps || [],
        loading: false
      });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '校园服务加载失败，请重试'
      });
    }
  },

  retryLoad() {
    this.loadData();
  },

  async reloadCalendar() {
    const service = this.data.service || {};
    const source = service.calendarSource || '';
    if (!(service.kind === 'schedule' || source)) return;
    const calendarData = await getCalendarSchedules(calendarQueryForService(service, this.data.selectedWeekStartDate));
    const calendar = calendarData.data || calendarData || {};
    const calendarDays = buildCalendarDays(calendar);
    const selectedWeekStartDate = calendar.startDate || this.data.selectedWeekStartDate;
    const isExamList = isExamService(service);
    const weekOptions = isExamList ? [] : buildWeekOptions(selectedWeekStartDate, calendarDays);
    this.setData({
      calendar,
      calendarDays,
      calendarGrid: buildScheduleGrid(calendarDays),
      examItems: buildExamItems(calendarDays),
      isExamList,
      weekOptions,
      ...activeWeekState(weekOptions, selectedWeekStartDate),
      weekScrollIntoView: activeWeekViewId(selectedWeekStartDate),
      selectedWeekStartDate,
      selectedDate: selectedWeekStartDate
    });
  },

  switchWeek(event) {
    const startDate = event.currentTarget.dataset.startDate;
    if (!startDate || startDate === this.data.selectedWeekStartDate) return;
    this.setData({
      selectedWeekStartDate: startDate,
      weekScrollIntoView: activeWeekViewId(startDate)
    });
    this.reloadCalendar().catch((error) => console.error(error));
  },

  pickWeek(event) {
    const index = Number(event.detail.value);
    const option = this.data.weekOptions[index];
    if (!option || !option.startDate || option.startDate === this.data.selectedWeekStartDate) return;
    this.setData({
      selectedWeekStartDate: option.startDate,
      weekPickerIndex: index,
      selectedWeekText: option.fullRange || option.range || '',
      weekScrollIntoView: activeWeekViewId(option.startDate)
    });
    this.reloadCalendar().catch((error) => console.error(error));
  },

  goBack() {
    const pages = getCurrentPages();
    if (pages.length > 1) {
      wx.navigateBack();
      return;
    }
    wx.switchTab({ url: '/pages/campus/index' });
  },

  shiftWeek(event) {
    const delta = Number(event.currentTarget.dataset.delta || 0);
    const base = this.data.selectedWeekStartDate
      ? new Date(`${this.data.selectedWeekStartDate}T00:00:00`)
      : mondayOf(new Date());
    const next = dateToYmd(addDays(base, delta * 7));
    this.setData({
      selectedWeekStartDate: next,
      weekScrollIntoView: activeWeekViewId(next)
    });
    this.reloadCalendar().catch((error) => console.error(error));
  },

  pickDate(event) {
    const value = event.detail.value;
    if (!value) return;
    const weekStart = dateToYmd(mondayOf(new Date(`${value}T00:00:00`)));
    this.setData({
      selectedDate: value,
      selectedWeekStartDate: weekStart,
      weekScrollIntoView: activeWeekViewId(weekStart)
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
