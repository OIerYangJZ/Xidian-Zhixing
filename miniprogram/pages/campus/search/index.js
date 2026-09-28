import { getPostsPage } from '../../../api/posts';
import { listRow } from '../../../utils/format';
import { followUser, searchUsers, unfollowUser } from '../../../api/user';
import { getHotTopics, getHotTopicSummary } from '../../../api/hot';
import { attachDisplayImages, hydrateDisplayImages, applyHydratedDisplayImages } from '../../../utils/feed_images';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const PAGE_SIZE = 20;

// Offered when nothing matches (handoff S3).
const SUGGESTED_TOPICS = ['图书馆', '组队', '二手', '考研', '失物招领'];

// 搜索 (handoff S1–S3): one query fills both 帖子 and 用户; a #query is a
// topic, headed by a card with 最新 / 最热. Before searching: recent
// searches and the hot list.
Page({
  data: {
    keyword: '',
    submitted: '',
    isTopic: false,
    topicName: '',
    tab: 'posts',
    sort: 'latest',
    posts: [],
    postTotal: 0,
    hasMore: false,
    loadingMore: false,
    users: [],
    suggestedTopics: SUGGESTED_TOPICS,
    history: [],
    hotTopics: [],
    hotSummary: '',
    hotErrorMessage: '',
    loading: false,
    errorMessage: ''
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    this.setData({ history: wx.getStorageSync('searchHistory') || [] });
    const keyword = options.keyword ? decodeURIComponent(options.keyword) : '';
    if (keyword) {
      this.setData({ keyword });
      this.search();
    } else {
      this.loadHotTopics();
    }
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  onInput(event) {
    this.setData({ keyword: event.detail.value });
  },

  clearKeyword() {
    this.setData({ keyword: '' });
  },

  onHistoryTap(event) {
    this.setData({ keyword: event.currentTarget.dataset.keyword });
    this.search();
  },

  onTopicTap(event) {
    this.setData({ keyword: `#${event.currentTarget.dataset.topic}` });
    this.search();
  },

  onTabTap(event) {
    this.setData({ tab: event.currentTarget.dataset.tab });
  },

  onSortTap(event) {
    const sort = event.currentTarget.dataset.sort;
    if (!sort || sort === this.data.sort) return;
    this.setData({ sort });
    this.search();
  },

  async search() {
    const raw = this.data.keyword.trim();
    if (!raw) {
      wx.showToast({ title: '请输入关键词', icon: 'none' });
      return;
    }
    // Tags are stored without #, so a topic searches by its name.
    const isTopic = raw.startsWith('#') && raw.length > 1;
    const keyword = isTopic ? raw.slice(1).trim() : raw;
    this.setData({
      loading: true,
      errorMessage: '',
      submitted: raw,
      isTopic,
      topicName: isTopic ? keyword : ''
    });
    // A topic is the exact tag; anything else matches title, text and tags.
    this._searchParams = { ...(isTopic ? { tag: keyword } : { keyword }), sort: this.data.sort, limit: PAGE_SIZE };
    this._searchSeq = (this._searchSeq || 0) + 1;
    const seq = this._searchSeq;
    try {
      const [page, users] = await Promise.all([
        getPostsPage({ ...this._searchParams, page: 1 }),
        searchUsers(keyword).catch(() => [])
      ]);
      if (seq !== this._searchSeq) return;
      const posts = page.items.map(listRow);
      this._searchPage = 1;
      const history = [raw, ...this.data.history.filter((item) => item !== raw)].slice(0, 8);
      wx.setStorageSync('searchHistory', history);
      const shown = posts.map(attachDisplayImages);
      this.setData({
        posts: shown,
        postTotal: page.total,
        hasMore: page.hasMore,
        users: users.map(this.decorateUser),
        history,
        loading: false
      });
      const hydrated = await hydrateDisplayImages(shown);
      this.setData({ posts: applyHydratedDisplayImages(this.data.posts, hydrated) });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '搜索失败，请重试' });
    }
  },

  async onReachBottom() {
    if (this.data.tab !== 'posts' || !this.data.hasMore || this.data.loadingMore || !this._searchParams) return;
    const seq = this._searchSeq;
    this.setData({ loadingMore: true });
    try {
      const page = await getPostsPage({ ...this._searchParams, page: this._searchPage + 1 });
      if (seq !== this._searchSeq) return;
      this._searchPage += 1;
      const known = new Set(this.data.posts.map((post) => post.id));
      const rows = page.items.map(listRow).filter((post) => !known.has(post.id)).map(attachDisplayImages);
      // New rows only, by path: the list is never re-sent whole.
      const patch = { hasMore: page.hasMore };
      rows.forEach((row, offset) => { patch[`posts[${this.data.posts.length + offset}]`] = row; });
      this.setData(patch);
      const hydrated = await hydrateDisplayImages(rows);
      const start = this.data.posts.length - rows.length;
      const imagePatch = {};
      rows.forEach((row, offset) => {
        if (hydrated[row.id]) imagePatch[`posts[${start + offset}].displayImages`] = hydrated[row.id];
      });
      if (Object.keys(imagePatch).length) this.setData(imagePatch);
    } catch (error) {
    } finally {
      this.setData({ loadingMore: false });
    }
  },

  decorateUser(user) {
    const mutual = Boolean(user.isFollowing && user.isFollower);
    return {
      ...user,
      meta: [user.college, `${user.postCount || 0} 帖子`, `${user.followerCount || 0} 粉丝`]
        .filter(Boolean).join(' · '),
      followLabel: mutual ? '互相关注' : (user.isFollowing ? '已关注' : '关注')
    };
  },

  async toggleFollow(event) {
    const index = Number(event.currentTarget.dataset.index);
    const user = this.data.users[index];
    if (!user || !user.id) return;
    const next = !user.isFollowing;
    try {
      if (next) await followUser(user.id);
      else await unfollowUser(user.id);
      const users = this.data.users.slice();
      users[index] = this.decorateUser({
        ...user,
        isFollowing: next,
        followerCount: Math.max(0, (Number(user.followerCount) || 0) + (next ? 1 : -1))
      });
      this.setData({ users });
    } catch (error) {
      wx.showToast({ title: '操作失败，请重试', icon: 'none' });
    }
  },

  clearHistory() {
    wx.removeStorageSync('searchHistory');
    this.setData({ history: [] });
  },

  async loadHotTopics() {
    this.setData({ hotErrorMessage: '' });
    try {
      const hotTopics = await getHotTopics();
      this.setData({ hotTopics });
    } catch (error) {
      this.setData({ hotErrorMessage: '热榜加载失败，请重试' });
    }
  },

  async summarizeHotTopics() {
    try {
      const result = await getHotTopicSummary();
      this.setData({ hotSummary: result.answer || '' });
    } catch (error) {
      wx.showToast({ title: '总结失败，请稍后再试', icon: 'none' });
    }
  },

  goHotPost(event) {
    const postId = event.currentTarget.dataset.postId;
    if (postId) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${postId}` });
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  goTagPosts(event) {
    const tag = event.currentTarget.dataset.tag;
    if (!tag) return;
    this.setData({ keyword: `#${tag}` });
    this.search();
  },

  openAuthorProfile(event) {
    const id = event.currentTarget.dataset.userId;
    if (id) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
  },

  goUserDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
  }
});
