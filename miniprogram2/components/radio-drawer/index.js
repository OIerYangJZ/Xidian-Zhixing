import { getUserInfo } from '../../api/auth';
import { getConversations } from '../../api/messages';
import { getLanguage } from '../../utils/i18n';
import { avatarInitial } from '../../utils/format';
import { retainLayerExit, cancelLayerExit, clearLayerMotion } from '../../utils/motion';

Component({
  properties: {
    open: {
      type: Boolean,
      value: false
    }
  },

  data: {
    navTop: 0,
    navHeight: 32,
    profile: null,
    conversations: [],
    avatarInitial: '电',
    errorMessage: '',
    english: false
  },

  lifetimes: {
    attached() {
      const { navTop, navHeight } = getApp().globalData;
      this.setData({ navTop, navHeight });
    },
    detached() {
      this._drawerRequest = (this._drawerRequest || 0) + 1;
      clearLayerMotion(this);
      this.setTabBarVisibility(false);
    }
  },

  observers: {
    open(value) {
      if (value) cancelLayerExit(this, 'open');
      else {
        retainLayerExit(this, 'open', undefined, this._drawerWasOpen);
        this._drawerRequest = (this._drawerRequest || 0) + 1;
      }
      this._drawerWasOpen = value;
      this.setTabBarVisibility(value);
      if (value) this.loadDrawerData();
    }
  },

  methods: {
    setTabBarVisibility(hidden) {
      const pages = getCurrentPages();
      const page = pages[pages.length - 1];
      const tabBar = page && typeof page.getTabBar === 'function' && page.getTabBar();
      if (tabBar) tabBar.setData({ drawerHidden: hidden });
      const method = hidden ? wx.hideTabBar : wx.showTabBar;
      if (typeof method !== 'function') return;
      method({ animation: false, fail() {} });
    },

    async loadDrawerData() {
      const request = this._drawerRequest = (this._drawerRequest || 0) + 1;
      this.setData({ errorMessage: '', english: getLanguage() === 'en' });
      try {
        const [profileResponse, conversations] = await Promise.all([
          getUserInfo(),
          getConversations()
        ]);
        if (request !== this._drawerRequest || !this.data.open) return;
        const profile = profileResponse.data || {};
        this.setData({
          profile,
          conversations: conversations.slice(0, 4),
          avatarInitial: avatarInitial(profile.nickname || profile.alias || profile.email || '电台')
        });
      } catch (error) {
        if (request !== this._drawerRequest || !this.data.open) return;
        this.setData({
          errorMessage: (error && error.data && error.data.message)
            || (error && error.message)
            || '抽屉信息加载失败，请重试'
        });
      }
    },

    retryLoad() {
      this.loadDrawerData();
    },

    close() {
      this._panelTouch = null;
      this.triggerEvent('close');
    },

    onPanelTouchStart(event) {
      this._panelTouch = event.touches && event.touches.length === 1 ? event.touches[0] : null;
    },

    onPanelTouchEnd(event) {
      const start = this._panelTouch;
      const end = event.changedTouches && event.changedTouches[0];
      this._panelTouch = null;
      if (!start || !end) return;
      const dx = end.clientX - start.clientX;
      const dy = Math.abs(end.clientY - start.clientY);
      if (dx < -64 && dy < 40) this.close();
    },

    onPanelTouchCancel() {
      this._panelTouch = null;
    },

    goFavorites() { this.close(); wx.navigateTo({ url: '/pages/profile/favorites/index' }); },
    goHistory() { this.close(); wx.navigateTo({ url: '/pages/ai/history/index' }); },
    goMessages() { this.close(); wx.switchTab({ url: '/pages/profile/conversations/index' }); },
    goReports() { this.close(); wx.navigateTo({ url: '/pages/profile/my-reports/index' }); },
    goProfile() {
      this.close();
      wx.navigateTo({ url: '/pages/profile/index' });
    },

    goConversation(event) {
      const item = this.data.conversations[Number(event.currentTarget.dataset.index)];
      if (!item) return;
      this.close();
      wx.navigateTo({
        url: `/pages/profile/chat/index?id=${item.id}&name=${encodeURIComponent(item.name || '私信')}&peerUserId=${encodeURIComponent(item.peerUserId || '')}&peerAvatar=${encodeURIComponent(item.avatarUrl || '')}`
      });
    },

    goMailbox() {
      this.close();
      wx.navigateTo({ url: '/pages/profile/feedback/index' });
    },

    goClubs() {
      this.close();
      wx.navigateTo({ url: '/pages/clubs/index' });
    },

    goAdmin() {
      this.close();
      wx.navigateTo({ url: '/pages/admin/index' });
    },

    goSettings() {
      this.close();
      wx.navigateTo({ url: '/pages/profile/settings/index' });
    }
  }
});
