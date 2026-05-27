import { getCampusMaps, getCampusQuickLinks, getCampusServices } from '../../api/campus';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';

Page({
  data: {
    navTop: 0,
    navHeight: 48,
    drawerOpen: false,
    services: [],
    maps: [],
    quickLinks: [],
    groupedServices: [],
    touchStartX: 0,
    touchStartY: 0
  },

  onLoad() {
    this.initCustomNav();
    if (!requireLoginPage()) return;
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
    const [servicesResponse, mapsResponse, quickLinksResponse] = await Promise.all([
      getCampusServices(),
      getCampusMaps(),
      getCampusQuickLinks()
    ]);
    const services = servicesResponse.data || servicesResponse || [];
    const maps = mapsResponse.data || mapsResponse || [];
    const quickLinks = quickLinksResponse.data || quickLinksResponse || [];
    const groups = [];
    services.forEach((service) => {
      let group = groups.find((item) => item.id === service.groupId);
      if (!group) {
        group = { id: service.groupId, name: service.groupName, items: [] };
        groups.push(group);
      }
      group.items.push(service);
    });
    this.setData({ services, maps, quickLinks, groupedServices: groups });
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
    wx.navigateTo({ url: `/pages/campus/service-detail/index?id=${service.id}&name=${encodeURIComponent(service.name)}` });
  },

  openMap() {
    wx.navigateTo({ url: '/pages/campus/map/index' });
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
