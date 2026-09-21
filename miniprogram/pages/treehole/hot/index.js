import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { getHotTopics, getHotTopicSummary } from '../../../api/hot';

Page({
  data: {
    topics: [],
    summary: '',
    loading: true,
    errorMessage: ''
  },
  onShow() { applyThemeAndLanguage(this); },
  async onLoad() {
    await this.loadTopics();
  },
  async loadTopics() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const topics = await getHotTopics();
      this.setData({ topics, loading: false });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '热榜加载失败，请重试'
      });
    }
  },
  retryLoad() {
    this.loadTopics();
  },
  async summarize() {
    try {
      const result = await getHotTopicSummary();
      this.setData({ summary: result.answer || '' });
    } catch (error) {
      this.setData({
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '热榜总结失败，请重试'
      });
    }
  },
  openPost(event) {
    const postId = event.currentTarget.dataset.postId;
    if (postId) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${postId}` });
  }
});
