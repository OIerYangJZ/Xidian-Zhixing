import { getDisplayMode, resolveDisplayMode } from '../utils/theme_i18n';
import { getLanguage } from '../utils/i18n';

// Each tab page owns a bar instance; hand the motion to the destination bar.
let pendingTransition = null;

Component({
  data: { selected: '', activeIndex: -1, motionFrom: 0, animating: false, navigating: false, themeClass: 'theme-reference', english: false, items: [{"pagePath":"pages/treehole/index","text":"首页","en":"Home","icon":"home"},{"pagePath":"pages/campus/index","text":"校园","en":"Campus","icon":"campus"},{"pagePath":"pages/ai/index","text":"知行 AI","en":"Zhixing AI","icon":"ai"},{"pagePath":"pages/profile/conversations/index","text":"消息","en":"Messages","icon":"mail"},{"pagePath":"pages/profile/index","text":"我的","en":"Profile","icon":"profile"}] },
  lifetimes: {
    attached() { this._detached = false; this.sync(); },
    detached() { this._detached = true; clearTimeout(this._motionTimer); }
  },
  pageLifetimes: {
    show() { this.sync(); },
    hide() { this.stopMotion(); }
  },
  methods: {
    stopMotion() {
      clearTimeout(this._motionTimer);
      this._motionTimer = null;
      this.setData({ animating: false });
    },
    sync() {
      const pages = getCurrentPages();
      const route = pages.length ? pages[pages.length - 1].route : '';
      const activeIndex = this.data.items.findIndex(item => item.pagePath === route);
      const motion = pendingTransition && pendingTransition.path === route ? pendingTransition : null;
      const update = {
        drawerHidden: !!(pages.length && pages[pages.length - 1].data && pages[pages.length - 1].data.drawerOpen),
        modalHidden: !!(pages.length && pages[pages.length - 1].data && (pages[pages.length - 1].data.conversationMenuOpen || pages[pages.length - 1].data.sidebarOpen || pages[pages.length - 1].data.customizing)),
        selected: route,
        activeIndex,
        navigating: motion || route !== this.data.selected ? false : this.data.navigating,
        themeClass: `theme-reference color-mode-${resolveDisplayMode(getDisplayMode())}`,
        english: getLanguage() === 'en'
      };
      if (motion) {
        pendingTransition = null;
        clearTimeout(this._motionTimer);
        update.motionFrom = motion.from;
        update.animating = true;
        this._motionTimer = setTimeout(() => {
          this._motionTimer = null;
          if (!this._detached) this.setData({ animating: false });
        }, 480);
      } else if (route !== this.data.selected) {
        clearTimeout(this._motionTimer);
        update.animating = false;
        update.motionFrom = activeIndex;
      }
      const changed = Object.fromEntries(Object.entries(update).filter(([key, value]) => this.data[key] !== value));
      if (Object.keys(changed).length) this.setData(changed);
    },
    navigate(event) {
      const path = event.currentTarget.dataset.path;
      if (!path || path === this.data.selected || this.data.navigating || !this.data.items.some(item => item.pagePath === path)) return;
      const motion = { path, from: this.data.activeIndex };
      pendingTransition = motion;
      this.setData({ navigating: true });
      wx.switchTab({
        url: '/' + path,
        success: () => { if (!this._detached) this.setData({ navigating: false }); },
        fail: () => {
          if (pendingTransition === motion) pendingTransition = null;
          if (!this._detached) this.setData({ navigating: false });
        }
      });
    }
  }
});
