import { getDisplayMode, resolveDisplayMode } from '../utils/theme_i18n';
import { getLanguage } from '../utils/i18n';
Component({
  data: { selected: '', themeClass: 'theme-reference', english: false, items: [{"pagePath":"pages/treehole/index","text":"主页","en":"Home","icon":"home"},{"pagePath":"pages/campus/search/index","text":"搜索","en":"Search","icon":"search"},{"pagePath":"pages/ai/index","text":"AI","en":"AI","icon":"ai"},{"pagePath":"pages/profile/notifications/index","text":"通知","en":"Notifications","icon":"bell"},{"pagePath":"pages/profile/conversations/index","text":"聊天","en":"Chat","icon":"chat"}] },
  lifetimes: { attached() { this.sync(); } },
  pageLifetimes: { show() { this.sync(); } },
  methods: {
    sync() {
      const pages = getCurrentPages();
      this.setData({
        selected: pages.length ? pages[pages.length - 1].route : '',
        themeClass: `theme-reference color-mode-${resolveDisplayMode(getDisplayMode())}`,
        english: getLanguage() === 'en'
      });
    },
    navigate(event) {
      const path = event.currentTarget.dataset.path;
      if (path !== this.data.selected) wx.switchTab({ url: '/' + path });
    }
  }
});
