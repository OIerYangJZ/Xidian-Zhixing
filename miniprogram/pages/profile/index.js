import { getUserInfo } from '../../api/auth';
import { getFollowers, getFollowing } from '../../api/user';
import { avatarInitial, resolveUrl } from '../../utils/format';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';

// 我的 (handoff A4): the profile card, four content entries and the menu.
// The content lists are their own pages now, not tabs here.
const QUICK_ENTRIES = [
  { key: 'posts', label: '我的发布', icon: 'edit', tone: 'primary', url: '/pages/profile/my-posts/index' },
  { key: 'comments', label: '我的评论', icon: 'comment', tone: 'info', url: '/pages/profile/my-comments/index' },
  { key: 'favorites', label: '我的收藏', icon: 'star', tone: 'accent', url: '/pages/profile/favorites/index' },
  { key: 'reports', label: '我的举报', icon: 'flag', tone: 'seal', url: '/pages/profile/my-reports/index' }
];

const MENU = [
  { key: 'hot', label: '热榜', icon: 'fire', tone: 'danger', url: '/pages/treehole/hot/index' },
  { key: 'college', label: '学院专区', icon: 'building', tone: 'info', url: '/pages/campus/college/index' },
  { key: 'clubs', label: '社团', icon: 'users', tone: 'success', url: '/pages/clubs/index' },
  { key: 'mailbox', label: '信箱', icon: 'mail', tone: 'accent', url: '/pages/profile/feedback/index' },
  { key: 'admin', label: '管理', icon: 'shield', tone: 'neutral', url: '/pages/admin/index', adminOnly: true, note: '仅管理员' },
  { key: 'settings', label: '设置', icon: 'sliders', tone: 'neutral', url: '/pages/profile/settings/index', note: '账号 · 隐私 · 通知 · 外观' }
];

const buildProfile = (raw = {}) => {
  const nickname = raw.nickname || raw.alias || '';
  return {
    ...raw,
    nickname,
    avatarInitial: avatarInitial(nickname || '匿名同学'),
    avatarUrl: resolveUrl(raw.avatarUrl || ''),
    backgroundImageUrl: resolveUrl(raw.backgroundImageUrl || '')
  };
};

const buildFollowUser = (raw = {}) => {
  const nickname = raw.nickname || raw.alias || raw.name || '西电同学';
  return {
    ...raw,
    id: String(raw.id || raw.userId || ''),
    nickname,
    avatarInitial: avatarInitial(nickname),
    avatarUrl: resolveUrl(raw.avatarUrl || ''),
    isMutual: Boolean(raw.isFollowing && raw.isFollower)
  };
};

Page({
  data: {
    quickEntries: QUICK_ENTRIES,
    menu: MENU.filter((item) => !item.adminOnly),
    userInfo: null,
    followers: [],
    following: [],
    loadingProfile: true,
    profileError: '',
    showFollowSheet: false,
    followSheetTitle: '',
    followSheetUsers: [],
    followSheetMutualUsers: [],
    followSheetOtherUsers: [],
    navTop: 0,
    navHeight: 48
  },

  onLoad() {
    this._didInitialShow = false;
    applyThemeAndLanguage(this);
    this.initCustomNav();
    if (!requireLoginPage()) return;
    this.loadInitialData().catch((error) => {
      console.error('[profile initial load failed]', error);
    });
  },

  onShow() {
    applyThemeAndLanguage(this);
    this.initCustomNav();
    if (!requireLoginPage()) return;
    if (!this._didInitialShow) {
      this._didInitialShow = true;
      return;
    }
    this.refreshProfile().catch((error) => {
      console.error('[profile refresh failed]', error);
    });
  },

  initCustomNav() {
    const app = getApp();
    this.setData({
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32
    });
  },

  onPullDownRefresh() {
    this.refreshAll()
      .catch((error) => {
        console.error('[profile pull refresh failed]', error);
      })
      .finally(() => wx.stopPullDownRefresh());
  },

  loadInitialData() {
    return this.refreshProfile();
  },

  refreshAll() {
    return this.refreshProfile();
  },

  async refreshProfile() {
    this.setData({ loadingProfile: true, profileError: '' });
    try {
      const [profileResponse, followers, following] = await Promise.all([
        getUserInfo(),
        getFollowers(),
        getFollowing()
      ]);
      const userInfo = buildProfile(profileResponse.data);
      this.setData({
        userInfo,
        menu: MENU.filter((item) => !item.adminOnly || userInfo.isAdmin),
        followers: followers.map(buildFollowUser),
        following: following.map(buildFollowUser)
      });
    } catch (error) {
      this.setData({ profileError: '个人资料或关注数据加载失败，请重试' });
    } finally {
      this.setData({ loadingProfile: false });
    }
  },

  openEntry(event) {
    const url = event.currentTarget.dataset.url;
    if (url && requireLoginPage()) wx.navigateTo({ url });
  },

  goToEditProfile() {
    if (!requireLoginPage()) return;
    wx.navigateTo({ url: '/pages/profile/edit-profile/index' });
  },

  goToSettings() {
    if (!requireLoginPage()) return;
    wx.navigateTo({ url: '/pages/profile/settings/index' });
  },

  openFollowSheet(event) {
    if (this.data.profileError) {
      wx.showToast({ title: '关注数据尚未加载，请先重试', icon: 'none' });
      return;
    }
    const type = event.currentTarget.dataset.type;
    const users = type === 'following' ? this.data.following : this.data.followers;
    const title = type === 'following' ? '关注' : '粉丝';
    const mutual = users.filter((item) => item.isMutual);
    const others = users.filter((item) => !item.isMutual);
    this.setData({
      showFollowSheet: true,
      followSheetTitle: title,
      followSheetUsers: users,
      followSheetMutualUsers: mutual,
      followSheetOtherUsers: others
    });
  },

  closeFollowSheet() {
    this.setData({
      showFollowSheet: false,
      followSheetTitle: '',
      followSheetUsers: [],
      followSheetMutualUsers: [],
      followSheetOtherUsers: []
    });
  },

  stopTouchMove() {},

  showShareToast() {
    wx.showToast({ title: '链接已复制', icon: 'none', duration: 1000 });
  }
});
