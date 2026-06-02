import { getPosts } from '../../../api/posts';
import { searchUsers } from '../../../api/user';
import { getHotTopics, getHotTopicSummary } from '../../../api/hot';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const SORT_OPTIONS = [
  { label: '最新', value: 'latest' },
  { label: '热度', value: 'hot' },
  { label: '点赞', value: 'likes' }
];

Page({
  data: {
    keyword: '',
    activeType: 'hot',
    sortOptions: SORT_OPTIONS,
    activeSort: 'hot',
    posts: [],
    users: [],
    hotTopics: [],
    hotSummary: '',
    history: [],
    searched: false,
    loading: false
  },

  onLoad(options) {
    if (options.keyword) {
      this.setData({ keyword: decodeURIComponent(options.keyword) });
    }
    if (!requireLoginPage()) return;
    this.setData({ history: wx.getStorageSync('searchHistory') || [] });
    if (this.data.keyword) {
      this.setData({ activeType: 'posts' });
      this.search();
    } else {
      this.loadHotTopics();
    }
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.setData({ history: wx.getStorageSync('searchHistory') || [] });
    if (this.data.keyword && !this.data.searched) {
      this.setData({ activeType: 'posts' });
      this.search();
    }
  },

  onInput(event) {
    const keyword = event.detail.value;
    this.setData({ keyword });
    if (keyword.trim() && this.data.activeType === 'hot') {
      this.setData({ activeType: 'posts' });
    }
  },

  onHistoryTap(event) {
    this.setData({ keyword: event.currentTarget.dataset.keyword });
    this.search();
  },

  onSortTap(event) {
    this.setData({ activeSort: event.currentTarget.dataset.sort });
    if (this.data.searched || this.data.keyword.trim()) this.search();
  },

  onTypeTap(event) {
    const type = event.currentTarget.dataset.type;
    if (!type || type === this.data.activeType) return;
    this.setData({ activeType: type });
    if (type === 'hot') {
      this.loadHotTopics();
    } else if (this.data.searched || this.data.keyword.trim()) {
      this.search();
    }
  },

  async search() {
    const keyword = this.data.keyword.trim();
    if (this.data.activeType === 'hot') {
      this.loadHotTopics();
      return;
    }
    if (!keyword && this.data.activeType === 'posts') {
      wx.showToast({ title: '请输入关键词', icon: 'none' });
      return;
    }
    if (!keyword && this.data.activeType === 'users') {
      wx.showToast({ title: '请输入用户关键词', icon: 'none' });
      return;
    }
    this.setData({ loading: true, searched: true });
    try {
      let posts = this.data.posts;
      let users = this.data.users;
      if (this.data.activeType === 'posts') {
        posts = await getPosts({
          keyword,
          sort: this.data.activeSort
        });
      } else {
        users = await searchUsers(keyword);
      }
      const history = keyword
        ? [keyword, ...this.data.history.filter((item) => item !== keyword)].slice(0, 8)
        : this.data.history;
      if (keyword) wx.setStorageSync('searchHistory', history);
      this.setData({ posts, users, history, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  clearHistory() {
    wx.removeStorageSync('searchHistory');
    this.setData({ history: [] });
  },

  async loadHotTopics() {
    this.setData({ loading: true, searched: false });
    try {
      const hotTopics = await getHotTopics();
      this.setData({ hotTopics, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  async summarizeHotTopics() {
    const result = await getHotTopicSummary();
    this.setData({ hotSummary: result.answer || '' });
  },

  goHotPost(event) {
    const postId = event.currentTarget.dataset.postId;
    if (postId) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${postId}` });
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  goUserDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
  }
});
