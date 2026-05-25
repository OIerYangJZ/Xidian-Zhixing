import { getAnnouncementFilters, getAnnouncementList, getDailySummary } from '../../api/announcements';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';
import { requireLoginPage } from '../../utils/auth_guard';

Page({
  data: {
    navTop: 0,
    navHeight: 48,
    drawerOpen: false,
    announcements: [],
    filters: {},
    dailySummary: null,
    activeType: '',
    preferredCollege: '',
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
    const menuButton = wx.getMenuButtonBoundingClientRect();
    this.setData({ navTop: menuButton.top, navHeight: menuButton.height });
  },

  async loadData() {
    const [announcements, filters, dailySummary] = await Promise.all([
      getAnnouncementList({ type: this.data.activeType, preferredCollege: this.data.preferredCollege }),
      getAnnouncementFilters(),
      getDailySummary()
    ]);
    this.setData({ announcements, filters, dailySummary });
  },

  selectType(event) {
    const type = event.currentTarget.dataset.type || '';
    this.setData({ activeType: type }, () => this.loadData());
  },

  openDetail(event) {
    wx.navigateTo({ url: `/pages/announcements/detail/index?id=${event.currentTarget.dataset.id}` });
  },

  openDrawer() {
    this.setData({ drawerOpen: true });
  },

  closeDrawer() {
    this.setData({ drawerOpen: false });
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
