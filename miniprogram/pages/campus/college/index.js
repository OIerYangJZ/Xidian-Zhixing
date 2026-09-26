import { getColleges } from '../../../api/campus';
import { getPosts } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    colleges: [],
    activeCollege: '',
    posts: [],
    loading: true,
    errorMessage: ''
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    if (options && options.name) {
      this.setData({ activeCollege: decodeURIComponent(options.name) });
    }
    this._didLoadData = true;
    this.loadCollege();
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    if (!this._didLoadData) {
      this._didLoadData = true;
      this.loadCollege();
    }
  },

  // The college list is fetched once; switching colleges only reloads posts.
  async loadCollege() {
    const requested = this.data.activeCollege;
    this.setData({ loading: true, errorMessage: '' });
    try {
      let { colleges } = this.data;
      if (!colleges.length) {
        const collegesRes = await getColleges();
        colleges = ((collegesRes && collegesRes.data) || []).map((item) => item.name || item);
        this.setData({ colleges });
      }
      const activeCollege = this.data.activeCollege || colleges[0] || '';
      const posts = activeCollege ? await getPosts({ keyword: activeCollege, sort: 'latest' }) : [];
      // A reply for a college the user already switched away from.
      if (this.data.activeCollege !== requested && this.data.activeCollege !== activeCollege) return;
      this.setData({
        activeCollege,
        posts,
        loading: false
      });
    } catch (error) {
      if (this.data.activeCollege !== requested) return;
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '学院内容加载失败，请重试'
      });
    }
  },

  retryLoad() {
    this.loadCollege();
  },

  onCollegeTap(event) {
    const name = event.currentTarget.dataset.name;
    if (!name || name === this.data.activeCollege) return;
    this.setData({ activeCollege: name, posts: [] });
    this.loadCollege();
  },

  askCollege() {
    wx.navigateTo({
      url: `/pages/ai/chat/index?q=${encodeURIComponent(`${this.data.activeCollege} 有哪些近期讨论？`)}`
    });
  },

  searchCollege() {
    wx.navigateTo({
      url: `/pages/campus/search/index?keyword=${encodeURIComponent(this.data.activeCollege)}`
    });
  },

  goTagPosts(event) {
    const tag = event.currentTarget.dataset.tag;
    if (tag) wx.navigateTo({ url: `/pages/campus/search/index?keyword=${encodeURIComponent(`#${tag}`)}` });
  },

  openAuthorProfile(event) {
    const id = event.currentTarget.dataset.userId;
    if (id) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  }
});
