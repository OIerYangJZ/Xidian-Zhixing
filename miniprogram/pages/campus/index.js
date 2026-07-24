import { getCampusServices, getTodaySchedules } from '../../api/campus';
import { getUserInfo } from '../../api/auth';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';
import { avatarInitial } from '../../utils/format';
import { openAppTarget } from '../../utils/navigation';

Page({
  data: {
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
    this.loadUserInfo();
    this.loadData();
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

  async loadData() {
    this.setData({ errorMessage: '' });
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
      usableServices.forEach((service) => {
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
    wx.navigateTo({ url: '/pages/campus/auth-center/index?system=ids' });
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
