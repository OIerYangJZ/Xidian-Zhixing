import { getMyActivityPage } from '../../../api/posts';
import { formatTime } from '../../../utils/format';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

// 互动: what one did, newest first (GET /api/users/me/activity) — posts,
// comments, likes, saves, reposts and follows.  Items whose post is gone or
// no longer visible are left out by the server.
const PAGE_SIZE = 20;
const LOOKS = {
  post: { verb: '发布了帖子', icon: 'edit', tone: 'primary' },
  comment: { verb: '评论了', icon: 'comment', tone: 'info' },
  like_post: { verb: '赞了帖子', icon: 'heart', tone: 'danger' },
  like_comment: { verb: '赞了评论', icon: 'heart', tone: 'danger' },
  favorite: { verb: '收藏了', icon: 'star', tone: 'accent' },
  repost: { verb: '转发了', icon: 'forward', tone: 'success' },
  follow: { verb: '关注了', icon: 'user', tone: 'neutral' }
};

const decorate = (item) => {
  const look = LOOKS[item.type] || { verb: '互动', icon: 'bell', tone: 'neutral' };
  return {
    ...item,
    ...look,
    // One's own anonymous post is labelled so, as nobody else sees the name.
    verb: item.type === 'post' && item.isAnonymous ? '匿名发布了帖子' : look.verb,
    target: item.type === 'follow'
      ? ((item.user && item.user.nickname) || '同学')
      : ((item.post && item.post.title) || '原帖'),
    quote: item.content || '',
    timeText: formatTime(item.createdAt)
  };
};

Page({
  data: {
    loading: true,
    items: [],
    page: 1,
    hasMore: false,
    loadingMore: false,
    errorMessage: ''
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadFirstPage();
  },

  onPullDownRefresh() {
    this.loadFirstPage().finally(() => wx.stopPullDownRefresh());
  },

  async loadFirstPage() {
    this.setData({ loading: !this.data.items.length, errorMessage: '' });
    try {
      const result = await getMyActivityPage({ page: 1, limit: PAGE_SIZE });
      this.setData({ items: result.items.map(decorate), page: 1, hasMore: result.hasMore, loading: false });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '互动记录加载失败，请重试'
      });
    }
  },

  async onReachBottom() {
    if (!this.data.hasMore || this.data.loadingMore) return;
    this.setData({ loadingMore: true });
    try {
      const next = this.data.page + 1;
      const result = await getMyActivityPage({ page: next, limit: PAGE_SIZE });
      const seen = new Set(this.data.items.map((item) => item.id));
      this.setData({
        items: this.data.items.concat(result.items.filter((item) => !seen.has(item.id)).map(decorate)),
        page: next,
        hasMore: result.hasMore
      });
    } catch (error) {
    } finally {
      this.setData({ loadingMore: false });
    }
  },

  retryLoad() {
    this.loadFirstPage();
  },

  openItem(event) {
    const item = this.data.items[Number(event.currentTarget.dataset.index)];
    if (!item) return;
    if (item.type === 'follow') {
      if (item.user && item.user.userId) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${item.user.userId}` });
      return;
    }
    if (!item.post || !item.post.id) return;
    const comment = item.commentId ? `&commentId=${item.commentId}` : '';
    wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${item.post.id}${comment}` });
  }
});
