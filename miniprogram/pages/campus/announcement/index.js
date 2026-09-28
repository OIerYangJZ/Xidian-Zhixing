import { getAnnouncement } from '../../../api/announcements';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

// One announcement.  The original page, when there is one, is copied rather
// than opened: an arbitrary site cannot be shown in a web-view.
Page({
  data: {
    id: '',
    item: null,
    loading: true,
    errorMessage: ''
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    this.setData({ id: decodeURIComponent(options.id || '') });
    this.load();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  async load() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const item = await getAnnouncement(this.data.id);
      this.setData({ item, loading: false });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: Number(error && error.statusCode) === 404
          ? '公告不存在或已撤回'
          : ((error && error.data && error.data.message) || '公告加载失败，请重试')
      });
    }
  },

  copyOriginal() {
    const url = this.data.item && this.data.item.originalUrl;
    if (url) wx.setClipboardData({ data: url });
  }
});
