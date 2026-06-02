import { getUserInfo } from '../../api/auth';
import { getConversations } from '../../api/messages';
import { avatarInitial } from '../../utils/format';

Component({
  properties: {
    open: {
      type: Boolean,
      value: false
    }
  },

  data: {
    profile: null,
    conversations: [],
    avatarInitial: '电'
  },

  observers: {
    open(value) {
      if (value) this.loadDrawerData();
    }
  },

  methods: {
    async loadDrawerData() {
      const [profileResponse, conversations] = await Promise.all([
        getUserInfo(),
        getConversations()
      ]);
      const profile = profileResponse.data || {};
      this.setData({
        profile,
        conversations: conversations.slice(0, 4),
        avatarInitial: avatarInitial(profile.nickname || profile.alias || profile.email || '电台')
      });
    },

    close() {
      this.triggerEvent('close');
    },

    stop() {},

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

    goSettings() {
      this.close();
      wx.navigateTo({ url: '/pages/profile/settings/index' });
    }
  }
});
