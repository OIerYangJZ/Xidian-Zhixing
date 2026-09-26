import { userIdFromScannedLink, userShareLink } from '../../../utils/share_links';
import { blockUserGlobally, followUser, getPublicUser, unblockUserGlobally, unfollowUser } from '../../../api/user';
import { getPostsPage, reportTarget } from '../../../api/posts';
import { createDirectConversation } from '../../../api/messages';
import { attachDisplayImages } from '../../../utils/feed_images';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const REPORT_REASONS = ['广告引流', '人身攻击', '违规内容', '垃圾信息', '其他'];

// 主页 (handoff U1–U3): the cover under a custom bar, the profile with
// 私信 / 关注, then TA 的帖子. 「⋯」 copies the link, blocks or reports; once
// blocked, the posts give way to a note and 关注 / 私信 to 解除屏蔽.
const PAGE_SIZE = 20;

// What anyone else sees here, and what postCount counts: on their own page
// the owner would otherwise also get their anonymous, private and unreviewed
// posts, relabelled with their name.
const isPublicPost = (post) => !post.isAnonymous
  && post.visibility !== 'private'
  && ['approved', 'resolved'].includes(post.reviewStatus);

Page({
  data: {
    userId: '',
    profile: null,
    posts: [],
    page: 1,
    hasMore: false,
    loadingMore: false,
    loading: true,
    errorMessage: '',
    busy: false,
    navTop: 44,
    navHeight: 32
  },

  onShow() {
    const app = getApp();
    this.setData({ navTop: app.globalData.navTop || 44, navHeight: app.globalData.navHeight || 32 });
    applyThemeAndLanguage(this);
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    const userId = options.id || userIdFromScannedLink(options.q);
    this.setData({ userId });
    if (userId) this.loadProfile();
  },

  decorate(profile) {
    const mutual = Boolean(profile.isFollowing && profile.isFollower);
    return {
      ...profile,
      name: profile.nickname || profile.alias || '西电同学',
      levelLabel: `Lv.${profile.isLevelOneUser ? 1 : (profile.userLevel || 2)}`,
      schoolLine: [profile.college, profile.major].filter(Boolean).join(' · '),
      followLabel: mutual ? '互相关注' : (profile.isFollowing ? '已关注' : '关注')
    };
  },

  async loadProfile() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const profile = this.decorate(await getPublicUser(this.data.userId));
      const page = await this.fetchPublicPage(1, profile);
      this.setData({
        profile,
        posts: page.rows,
        page: page.page,
        hasMore: page.hasMore,
        loading: false
      });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '主页加载失败，请重试'
      });
    }
  },

  // Rows show this page's owner, not a stale alias from the feed.
  ownerRows(posts, profile) {
    return posts.filter(isPublicPost).map((post) => Object.assign(attachDisplayImages(post), {
      authorAlias: profile.name,
      authorAvatarUrl: profile.avatarUrl || '',
      authorInitial: profile.avatarInitial
    }));
  },

  // From page `first` on until one yields a public row or the list ends: on
  // the owner's own page a whole server page can be anonymous or private,
  // and a page with no rows gives onReachBottom nothing to scroll to.
  async fetchPublicPage(first, profile) {
    let page = first;
    for (;;) {
      const result = await getPostsPage({ authorId: this.data.userId, page, limit: PAGE_SIZE });
      const rows = this.ownerRows(result.items, profile);
      if (rows.length || !result.hasMore) return { rows, page, hasMore: result.hasMore };
      page += 1;
    }
  },

  async onReachBottom() {
    if (!this.data.hasMore || this.data.loadingMore || !this.data.profile) return;
    this.setData({ loadingMore: true });
    try {
      const page = await this.fetchPublicPage(this.data.page + 1, this.data.profile);
      this.setData({
        posts: this.data.posts.concat(page.rows),
        page: page.page,
        hasMore: page.hasMore
      });
    } finally {
      this.setData({ loadingMore: false });
    }
  },

  retryLoad() {
    this.loadProfile();
  },

  goBack() {
    if (getCurrentPages().length > 1) wx.navigateBack();
    else wx.switchTab({ url: '/pages/treehole/index' });
  },

  showMore() {
    const profile = this.data.profile;
    if (!profile) return;
    const blocked = Boolean(profile.isBlockedByMe);
    const actions = ['复制主页链接', blocked ? '解除屏蔽' : '屏蔽', '举报'];
    wx.showActionSheet({
      itemList: actions,
      success: (res) => {
        const action = actions[res.tapIndex];
        if (action === '复制主页链接') this.copyProfileLink();
        else if (action === '屏蔽') this.confirmBlock();
        else if (action === '解除屏蔽') this.setBlocked(false);
        else if (action === '举报') this.reportUser();
      }
    });
  },

  copyProfileLink() {
    if (!this.data.userId) return;
    wx.setClipboardData({ data: userShareLink(this.data.userId) });
  },

  confirmBlock() {
    wx.showModal({
      title: `屏蔽 ${this.data.profile.name}？`,
      content: '屏蔽后不再看到 TA 的帖子，也不会收到 TA 的私信。',
      confirmText: '屏蔽',
      confirmColor: '#B3261E',
      success: (res) => {
        if (res.confirm) this.setBlocked(true);
      }
    });
  },

  async setBlocked(block) {
    if (this.data.busy) return;
    this.setData({ busy: true });
    try {
      if (block) await blockUserGlobally(this.data.userId);
      else await unblockUserGlobally(this.data.userId);
      wx.showToast({ title: block ? '已屏蔽' : '已解除屏蔽', icon: 'none' });
      // The server keeps the follow and filters TA's posts while blocked:
      // reload both rather than guess them here.
      await this.loadProfile();
    } catch (error) {
      wx.showToast({ title: '操作失败，请重试', icon: 'none' });
    } finally {
      this.setData({ busy: false });
    }
  },

  unblock() {
    this.setBlocked(false);
  },

  reportUser() {
    wx.showActionSheet({
      itemList: REPORT_REASONS,
      success: (res) => {
        const reason = REPORT_REASONS[res.tapIndex];
        if (!reason) return;
        wx.showModal({
          title: `举报：${reason}`,
          editable: true,
          placeholderText: '补充说明（选填）',
          confirmText: '提交',
          success: async (modal) => {
            if (!modal.confirm) return;
            try {
              await reportTarget({
                targetType: 'user',
                targetId: this.data.userId,
                reason,
                description: String(modal.content || '').trim()
              });
              wx.showToast({ title: '举报已提交', icon: 'success' });
            } catch (error) {
              wx.showToast({ title: '举报失败，请重试', icon: 'none' });
            }
          }
        });
      }
    });
  },

  async toggleFollow() {
    const profile = this.data.profile;
    if (!profile || this.data.busy) return;
    this.setData({ busy: true });
    const next = !profile.isFollowing;
    try {
      if (next) await followUser(this.data.userId);
      else await unfollowUser(this.data.userId);
      this.setData({
        profile: this.decorate({
          ...profile,
          isFollowing: next,
          followerCount: Math.max(0, (Number(profile.followerCount) || 0) + (next ? 1 : -1))
        })
      });
    } catch (error) {
      wx.showToast({ title: '操作失败，请重试', icon: 'none' });
    } finally {
      this.setData({ busy: false });
    }
  },

  async messageUser() {
    if (!this.data.profile) return;
    try {
      const conversation = await createDirectConversation({ targetUserId: this.data.userId });
      wx.navigateTo({
        url: `/pages/profile/chat/index?id=${conversation.id}&name=${encodeURIComponent(conversation.name || this.data.profile.name)}&peerUserId=${encodeURIComponent(this.data.userId)}&peerAvatar=${encodeURIComponent(this.data.profile.avatarUrl || conversation.avatarUrl || '')}`
      });
    } catch (error) {
      const message = (error && error.data && error.data.message) || '无法发起私信';
      wx.showToast({ title: message, icon: 'none' });
    }
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  goTagPosts(event) {
    const tag = event.currentTarget.dataset.tag;
    if (tag) wx.navigateTo({ url: `/pages/campus/search/index?keyword=${encodeURIComponent(`#${tag}`)}` });
  },

  // Already on the author's page.
  openAuthorProfile() {}
});
