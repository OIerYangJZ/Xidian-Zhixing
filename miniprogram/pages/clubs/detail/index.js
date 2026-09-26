import { getClubDetail } from '../../../api/clubs';
import { normalizePost } from '../../../utils/format';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { applyHydratedDisplayImages, attachDisplayImages, hydrateDisplayImages } from '../../../utils/feed_images';

// Skips a malformed post instead of losing the whole club page.
const safePost = (raw) => {
  try {
    return normalizePost(raw);
  } catch (error) {
    return null;
  }
};

Page({
  data: { id: '', club: null, themeClass: '', loading: true, errorMessage: '' },
  onLoad(options) {
    this.setData({ id: options.id || '' });
    this.loadDetail();
  },
  onShow() {
    applyThemeAndLanguage(this);
  },
  async loadDetail() {
    if (!this.data.id) {
      this.setData({ loading: false, errorMessage: '缺少社团编号' });
      return;
    }
    this.setData({ loading: true, errorMessage: '' });
    try {
      const club = await getClubDetail(this.data.id);
      const posts = (Array.isArray(club.posts) ? club.posts : []).map(safePost).filter(Boolean)
        .map(attachDisplayImages);
      this.setData({
        club: Object.assign({}, club, {
          initial: String(club.name || '社').trim().charAt(0) || '社',
          posts
        }),
        loading: false
      });
      if (club.name) wx.setNavigationBarTitle({ title: club.name });
      const hydrated = await hydrateDisplayImages(posts);
      this.setData({ 'club.posts': applyHydratedDisplayImages(this.data.club.posts, hydrated) });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '社团信息加载失败，请重试'
      });
    }
  },
  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },
  openPost(event) {
    this.goPostDetail(event);
  },
  goTagPosts(event) {
    const tag = event.currentTarget.dataset.tag;
    if (tag) wx.navigateTo({ url: `/pages/campus/search/index?keyword=${encodeURIComponent(`#${tag}`)}` });
  },
  openAuthorProfile(event) {
    const id = event.currentTarget.dataset.userId;
    if (id) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
  }
});
