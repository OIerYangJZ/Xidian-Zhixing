import { getFollowers, getFollowing, getFriends } from '../../../api/user';
import { createDirectConversation } from '../../../api/messages';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const TITLE_MAP = {
  following: '关注',
  followers: '粉丝',
  friends: '好友'
};

const TABS = [
  { key: 'friends', label: '好友' },
  { key: 'following', label: '关注' },
  { key: 'followers', label: '粉丝' }
];

const EMPTY = {
  friends: ['还没有好友', '互相关注后会成为好友'],
  following: ['还没有关注任何人', '在同学的主页点「关注」'],
  followers: ['还没有粉丝', '被关注后会出现在这里']
};

Page({
  onShow() {
    applyThemeAndLanguage(this);
  },
  data: {
    type: 'friends',
    tabs: TABS,
    emptyTitle: EMPTY.friends[0],
    emptyMessage: EMPTY.friends[1],
    loading: true,
    users: [],
    errorMessage: ''
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    this.showType(TITLE_MAP[options.type] ? options.type : 'friends');
  },

  switchType(event) {
    const type = event.currentTarget.dataset.type;
    if (type && type !== this.data.type) this.showType(type);
  },

  showType(type) {
    wx.setNavigationBarTitle({ title: TITLE_MAP[type] });
    this.setData({ type, users: [], emptyTitle: EMPTY[type][0], emptyMessage: EMPTY[type][1] });
    this.loadData();
  },

  async loadData() {
    const { type } = this.data;
    this.setData({ loading: true, errorMessage: '' });
    try {
      const users = type === 'following'
        ? await getFollowing()
        : type === 'followers'
          ? await getFollowers()
          : await getFriends();
      // A reply for a tab the user already left.
      if (type !== this.data.type) return;
      this.setData({ users, loading: false });
    } catch (error) {
      if (type !== this.data.type) return;
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '关系列表加载失败，请重试'
      });
    }
  },

  retryLoad() {
    this.loadData();
  },

  openUser(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
  },

  async messageUser(event) {
    const id = event.currentTarget.dataset.id;
    const avatarUrl = event.currentTarget.dataset.avatar || '';
    if (!id) return;
    try {
      const conversation = await createDirectConversation({ targetUserId: id });
      wx.navigateTo({
        url: `/pages/profile/chat/index?id=${conversation.id}&name=${encodeURIComponent(conversation.name || '私信')}&peerUserId=${encodeURIComponent(id)}&peerAvatar=${encodeURIComponent(avatarUrl || conversation.avatarUrl || '')}`
      });
    } catch (error) {}
  }
});
