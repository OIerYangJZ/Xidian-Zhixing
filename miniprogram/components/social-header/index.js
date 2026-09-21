import { getUserInfo } from '../../api/auth';
import { avatarInitial } from '../../utils/format';
import { getLanguage } from '../../utils/i18n';
Component({
  options: { multipleSlots: true },
  properties: { fixed: Boolean, brand: { type: Boolean, value: true }, profile: { type: Object, value: null } },
  data: { drawerOpen: false, user: null, initial: '', navTop: 0, navHeight: 32, english: false, profileError: false },
  lifetimes: { attached() { this.setData({ navTop: getApp().globalData.navTop, navHeight: getApp().globalData.navHeight }); } },
  pageLifetimes: {
    async show() {
      this.setData({ english: getLanguage() === 'en' });
      if (!wx.getStorageSync('token') || this.data.profile) return;
      try {
        const response = await getUserInfo();
        this.setData({ user: response.data, profileError: false, initial: avatarInitial(response.data.nickname || response.data.alias || response.data.email) });
      } catch (error) {
        this.setData({ user: null, initial: '', profileError: true });
      }
    }
  },
  methods: {
    openDrawer() { this.setData({ drawerOpen: true }); },
    closeDrawer() { this.setData({ drawerOpen: false }); }
  }
});
