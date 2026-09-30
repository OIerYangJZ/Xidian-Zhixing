import { enterPage, enterContent, retainLayerExit, cancelLayerExit, clearLayerMotion } from '../../utils/motion';
import { getCampusServices, getCalendarSchedules } from '../../api/campus';
import { getUserInfo } from '../../api/auth';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';
import { avatarInitial } from '../../utils/format';
import { openAppTarget } from '../../utils/navigation';
import {
  CAMPUS_GROUPS, MAX_SHORTCUTS, schoolClock, prepareCampusServices,
  filterCampusServices, readCampusPreferences, buildCampusDay, canOpenCampusUrl
} from '../../utils/campus_workbench';

const errorText = (error) => error?.data?.message || error?.message || '连接失败，请重试';
const dateLabel = (date = '') => {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  return match ? `${Number(match[2])} 月 ${Number(match[3])} 日` : date;
};

Page({
  data: {
    navTop: 0, navHeight: 32,
    activeView: 'today', activeGroup: 'all', categories: CAMPUS_GROUPS,
    services: [], visibleServices: [], shortcuts: [], shortcutIds: [],
    loading: true, refreshing: false, serviceError: '', scheduleError: '', profileError: '',
    weekDays: [], selectedDate: '', todayDate: '', dayLabel: '', scheduleRows: [],
    focusSchedule: null, focusLabel: '', countdown: '', scheduleCount: 0, readTime: '',
    searchKeyword: '', userInfo: null, compact: false, showSchedule: true,
    scrollAnchor: '',
    customizing: false, draftShortcutIds: [], draftShortcuts: [], editorServices: [],
    draftCompact: false, draftShowSchedule: true
  },

  onLoad() {
    this.initCustomNav();
    applyThemeAndLanguage(this);
    if (requireLoginPage()) { this.syncAccount(); this.loadData(); }
  },

  onShow() {
    enterPage(this, { animate: false });
    applyThemeAndLanguage(this);
    this.initCustomNav();
    if (!requireLoginPage()) return;
    this.syncAccount();
    const scheduleUpdated = wx.getStorageSync('campusScheduleUpdatedAt');
    if (!this._loadedAt || Date.now() - this._loadedAt > 300000 || scheduleUpdated !== this._scheduleUpdated || this.data.todayDate !== schoolClock().date) this.loadData();
    else { this.restorePreferences(); this.updateSelectedDay(); }
    this.stopClock();
    this._clockTimer = setInterval(() => {
      if (this.data.todayDate !== schoolClock().date) this.loadData();
      else this.updateSelectedDay();
    }, 60000);
  },

  onHide() { this.stopClock(); this.closeCustomizer(); clearLayerMotion(this); },
  onUnload() { this.stopClock(); this.closeCustomizer(); clearLayerMotion(this); },
  stopClock() { if (this._clockTimer) clearInterval(this._clockTimer); this._clockTimer = null; },

  initCustomNav() {
    const { navTop, navHeight } = getApp().globalData;
    this.setData({ navTop: navTop || 44, navHeight: navHeight || 32 });
  },

  syncAccount() {
    const token = wx.getStorageSync('token');
    if (token === this._accountToken) return;
    this._accountToken = token;
    this._loadEpoch = (this._loadEpoch || 0) + 1;
    this._loadPromise = null;
    this._loadedAt = 0;
    this._preferenceKey = null;
    this.closeCustomizer();
    this.setData({ userInfo: null, weekDays: [], selectedDate: '', todayDate: '', scheduleRows: [], focusSchedule: null, readTime: '', shortcuts: [], shortcutIds: [], compact: false, showSchedule: true });
  },

  async loadData() {
    if (this._loadPromise) return this._loadPromise;
    this.setData({ loading: true });
    const startDate = schoolClock().date;
    const epoch = this._loadEpoch;
    const token = wx.getStorageSync('token');
    const pending = (async () => {
      const results = await Promise.allSettled([
        getCampusServices().then(response => ({ data:prepareCampusServices(response.data) })),
        getCalendarSchedules({ startDate, days: 7, source: 'all' }).then(response => {
          for (const day of response.data.days) {
            if (!/^\d{4}-\d{2}-\d{2}$/.test(day.date) || !Array.isArray(day.items)) throw new Error('日程响应格式无效');
          }
          return response;
        }), getUserInfo()
      ]);
      if (epoch !== this._loadEpoch || token !== wx.getStorageSync('token')) return;
      const [serviceResult, calendarResult, userResult] = results;
      const update = { loading: false };
      if (userResult.status === 'fulfilled') {
        const user = userResult.value.data;
        update.userInfo = { ...user, avatarInitial: avatarInitial(user.nickname || user.alias || '同学') };
        update.profileError = '';
        this._preferenceKey = user.id ? `campusWorkbench:${user.id}` : null;
      } else { update.userInfo = null; update.profileError = errorText(userResult.reason); this._preferenceKey = null; }
      if (serviceResult.status === 'fulfilled') {
        update.services = serviceResult.value.data;
        update.serviceError = '';
      } else update.serviceError = errorText(serviceResult.reason);
      const calendarData = calendarResult.status === 'fulfilled' ? calendarResult.value.data : null;
      update.todayDate = startDate;
      update.scheduleError = calendarData ? '' : errorText(calendarResult.reason);
      if (calendarData) {
        update.weekDays = calendarData.days.map(day => ({
          ...day, number: Number(day.date.slice(-2)), count: day.items.length,
          weekday: day.weekday || '一二三四五六日'[(new Date(day.date + 'T00:00:00Z').getUTCDay() + 6) % 7],
          isToday: day.date === update.todayDate
        }));
      }
      update.selectedDate = (update.weekDays || this.data.weekDays).some(day => day.date === this.data.selectedDate) ? this.data.selectedDate : update.todayDate;
      if (calendarData) update.readTime = schoolClock().time;
      this.setData(update);
      this.restorePreferences();
      this.updateSelectedDay();
      this._loadedAt = Date.now();
      this._scheduleUpdated = wx.getStorageSync('campusScheduleUpdatedAt');
    })();
    this._loadPromise = pending;
    try { await pending; } finally { if (this._loadPromise === pending) this._loadPromise = null; }
  },

  restorePreferences() {
    // Do not persist another account's layout when profile loading failed.
    const stored = this._preferenceKey ? wx.getStorageSync(this._preferenceKey) : null;
    const preferences = readCampusPreferences(stored, this.data.services);
    this.setData({
      ...preferences,
      shortcuts: preferences.shortcutIds.map(id => this.data.services.find(service => service.id === id)).filter(Boolean),
      visibleServices: filterCampusServices(this.data.services, this.data.activeGroup, this.data.searchKeyword)
    });
  },

  updateSelectedDay() {
    const day = this.data.weekDays.find(item => item.date === this.data.selectedDate);
    const model = buildCampusDay(day?.items || [], this.data.selectedDate);
    this.setData({
      scheduleRows: model.rows, focusSchedule: model.focus, focusLabel: model.focusLabel,
      countdown: model.countdown, scheduleCount: model.count, dayLabel: dateLabel(this.data.selectedDate)
    });
  },

  async refreshData() {
    if (this.data.refreshing) return;
    this.setData({ refreshing: true });
    try { await this.loadData(); } finally { this.setData({ refreshing: false }); }
  },
  retryLoad() { return this.loadData(); },

  switchView(event) {
    const activeView = event.currentTarget.dataset.view;
    if (!['today', 'services'].includes(activeView) || activeView === this.data.activeView) return;
    enterContent(this, { activeView, scrollAnchor: '' }, activeView === 'services' ? 1 : -1,
      () => this.setData({ scrollAnchor: 'workbench-top' }));
  },
  showAllServices() {
    this.setData({ activeGroup: 'all', searchKeyword: '', visibleServices: this.data.services });
    this.switchView({ currentTarget: { dataset: { view: 'services' } } });
  },
  selectDay(event) { this.setData({ selectedDate: event.currentTarget.dataset.date }); this.updateSelectedDay(); },
  selectGroup(event) {
    const activeGroup = event.currentTarget.dataset.group;
    this.setData({ activeGroup, visibleServices: filterCampusServices(this.data.services, activeGroup, this.data.searchKeyword) });
  },
  onServiceSearch(event) {
    const searchKeyword = event.detail.value;
    this.setData({ searchKeyword, visibleServices: filterCampusServices(this.data.services, this.data.activeGroup, searchKeyword) });
  },
  clearSearch() { this.setData({ searchKeyword: '', visibleServices: filterCampusServices(this.data.services, this.data.activeGroup) }); },

  openService(event) {
    const service = this.data.services.find(item => item.id === event.currentTarget.dataset.id);
    if (!service) return;
    if (!service.usable) { wx.navigateTo({ url: '/pages/campus/auth-center/index' }); return; }
    if (service.isMap) { wx.navigateTo({ url: '/pages/campus/map/index' }); return; }
    if (service.isSchedule) {
      wx.navigateTo({ url: `/pages/campus/service-detail/index?id=${encodeURIComponent(service.id)}&name=${encodeURIComponent(service.name)}&startDate=${encodeURIComponent(this.data.selectedDate || '')}` });
      return;
    }
    if (service.targets.length === 1) { this.openServiceTarget(service.targets[0]); return; }
    if (service.targets.length > 1) {
      wx.showActionSheet({ itemList: service.targets.map(action => action.label), success: result => this.openServiceTarget(service.targets[result.tapIndex]) });
      return;
    }
    wx.navigateTo({ url: '/pages/campus/auth-center/index' });
  },

  openServiceTarget(action) {
    if (!action) return;
    if (action.type === 'external' && !canOpenCampusUrl(action.url)) {
      wx.showModal({
        title: '需要在浏览器打开', content: '此入口暂不能在小程序内打开，可复制链接到浏览器访问学校服务。',
        confirmText: '复制链接', success: result => { if (result.confirm) wx.setClipboardData({ data: action.url }); }
      });
      return;
    }
    if (!openAppTarget(action)) wx.showToast({ title: '入口暂不可用', icon: 'none' });
  },

  openSchedule(event) {
    const source = event.currentTarget.dataset.source;
    const slug = source === 'examSchedules' ? 'exam' : source === 'experimentSchedules' ? 'experiment' : 'classtable';
    const service = this.data.services.find(item => item.slug === slug);
    if (!service) { wx.showToast({ title: '日程入口暂不可用', icon: 'none' }); return; }
    this.openService({ currentTarget: { dataset: { id: service.id } } });
  },
  openWeeklySchedule() { this.openSchedule({ currentTarget: { dataset: { source: 'courseSchedules' } } }); },
  syncCustomizerTab() {
    if (typeof this.getTabBar === 'function') {
      const bar = this.getTabBar();
      if (bar) bar.setData({ modalHidden: this.data.customizing });
    }
  },
  openCustomizer() {
    if (!this._preferenceKey) { wx.showToast({ title: '请先重新加载账户信息', icon: 'none' }); return; }
    wx.hideKeyboard();
    cancelLayerExit(this, 'customizing');
    this.setData({ customizing: true, draftShortcutIds: this.data.shortcutIds.slice(), draftCompact: this.data.compact, draftShowSchedule: this.data.showSchedule });
    this.updateEditor();
    this.syncCustomizerTab();
  },
  closeCustomizer() { retainLayerExit(this, 'customizing'); this.setData({ customizing: false }); this.syncCustomizerTab(); },
  updateEditor() {
    this.setData({
      draftShortcuts: this.data.draftShortcutIds.map(id => this.data.services.find(service => service.id === id)).filter(Boolean),
      editorServices: this.data.services.filter(service => service.usable).map(service => ({ ...service, selected: this.data.draftShortcutIds.includes(service.id) }))
    });
  },
  toggleShortcut(event) {
    const id = event.currentTarget.dataset.id;
    if (!this.data.services.some(service => service.id === id && service.usable)) return;
    const draftShortcutIds = this.data.draftShortcutIds.slice();
    const index = draftShortcutIds.indexOf(id);
    if (index >= 0) draftShortcutIds.splice(index, 1);
    else {
      if (draftShortcutIds.length >= MAX_SHORTCUTS) { wx.showToast({ title: '最多保留 8 个常用入口', icon: 'none' }); return; }
      draftShortcutIds.push(id);
    }
    this.setData({ draftShortcutIds }); this.updateEditor();
  },
  moveShortcut(event) {
    const index = Number(event.currentTarget.dataset.index);
    const next = index + Number(event.currentTarget.dataset.direction);
    const ids = this.data.draftShortcutIds.slice();
    if (!Number.isInteger(index) || index < 0 || index >= ids.length || ![-1, 1].includes(Number(event.currentTarget.dataset.direction)) || next < 0 || next >= ids.length) return;
    [ids[index], ids[next]] = [ids[next], ids[index]];
    this.setData({ draftShortcutIds: ids }); this.updateEditor();
  },
  toggleScheduleDisplay(event) { this.setData({ draftShowSchedule: !!event.detail.value }); },
  toggleCompactDisplay(event) { this.setData({ draftCompact: !!event.detail.value }); },
  resetLayout() {
    const defaults = readCampusPreferences(null, this.data.services);
    this.setData({ draftShortcutIds: defaults.shortcutIds, draftCompact: false, draftShowSchedule: true });
    this.updateEditor();
  },
  saveLayout() {
    if (!this._preferenceKey) { wx.showToast({ title: '请先重新加载账户信息', icon: 'none' }); return; }
    try {
      wx.setStorageSync(this._preferenceKey, { shortcutIds: this.data.draftShortcutIds.slice(), compact: this.data.draftCompact, showSchedule: this.data.draftShowSchedule });
      this.restorePreferences(); this.closeCustomizer();
    } catch (error) { wx.showToast({ title: '布局保存失败，请重试', icon: 'none' }); }
  }
});
