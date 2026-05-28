import { getCampusQuickLinks, getCampusServices, getTodaySchedules } from '../../api/campus';
import { getUserInfo } from '../../api/auth';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';
import { avatarInitial } from '../../utils/format';

Page({
  data: {
    navTop: 0,
    navHeight: 48,
    drawerOpen: false,
    services: [],
    quickLinks: [],
    groupedServices: [],
    todaySchedules: [],
    todayScheduleDate: '',
    userInfo: null,
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
  },

  initCustomNav() {
    const app = getApp();
    this.setData({
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32
    });
  },

  async loadData() {
    const [servicesResponse, quickLinksResponse, todaySchedulesResponse] = await Promise.all([
      getCampusServices(),
      getCampusQuickLinks(),
      getTodaySchedules()
    ]);
    const services = servicesResponse.data || servicesResponse || [];
    const quickLinks = quickLinksResponse.data || quickLinksResponse || [];
    const scheduleData = todaySchedulesResponse.data || todaySchedulesResponse;
    const todaySchedules = scheduleData.items;
    const groups = [];
    services.forEach((service) => {
      let group = groups.find((item) => item.id === service.groupId);
      if (!group) {
        group = { id: service.groupId, name: service.groupName, items: [] };
        groups.push(group);
      }
      group.items.push(service);
    });
    this.setData({
      services,
      quickLinks,
      groupedServices: groups,
      todaySchedules,
      todayScheduleDate: scheduleData.date
    });
  },

  async loadUserInfo() {
    const response = await getUserInfo();
    const user = response.data || {};
    this.setData({
      userInfo: {
        ...user,
        avatarInitial: avatarInitial(user.nickname || user.alias || user.email)
      }
    });
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
    if (service.name === '移动门户跳转') {
      const url = encodeURIComponent('https://xxcapp.xidian.edu.cn/site/xidianPage/home');
      wx.navigateTo({ url: `/pages/campus/webview/index?url=${url}` });
      return;
    }
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
