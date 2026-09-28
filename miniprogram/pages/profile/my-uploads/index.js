import { getMyUploads } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { hydrateDisplayImages } from '../../../utils/feed_images';

// 我的上传: every image one uploaded, with its review state and the post it
// is in.  Images never attached to a post stay here until they are used.
const STATUS = {
  approved: { label: '已通过', tone: 'success' },
  pending: { label: '审核中', tone: 'warning' },
  rejected: { label: '未通过', tone: 'danger' }
};

Page({
  data: {
    loading: true,
    errorMessage: '',
    items: []
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.load();
  },

  onPullDownRefresh() {
    this.load().finally(() => wx.stopPullDownRefresh());
  },

  async load() {
    this.setData({ loading: !this.data.items.length, errorMessage: '' });
    try {
      const uploads = await getMyUploads();
      const shown = (await hydrateDisplayImages([{ id: 'uploads', imageUrls: uploads.map((item) => item.url) }])).uploads
        || uploads.map((item) => item.url);
      this.setData({
        loading: false,
        items: uploads.map((item, index) => ({
          ...item,
          displayUrl: shown[index] || item.url,
          ...(STATUS[item.status] || STATUS.pending)
        }))
      });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message) || (error && error.message) || '加载失败，请重试'
      });
    }
  },

  onItemTap(event) {
    const item = this.data.items[Number(event.currentTarget.dataset.index)];
    if (!item) return;
    if (item.postId) {
      wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${item.postId}` });
      return;
    }
    wx.previewImage({ current: item.displayUrl, urls: this.data.items.map((row) => row.displayUrl) });
  }
});
