import { getHotTopics, getHotTopicSummary } from '../../../api/hot';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const messageOf = (error, fallback) => (error && error.data && error.data.message)
  || (error && error.message)
  || fallback;

Page({
  data: {
    topics: [],
    summary: '',
    summarizing: false,
    summaryError: '',
    loading: true,
    errorMessage: ''
  },
  onShow() {
    applyThemeAndLanguage(this);
  },
  async onLoad() {
    await this.loadTopics();
  },
  async loadTopics() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const topics = (await getHotTopics()).map((topic) => Object.assign({}, topic, {
        hotScore: Math.round(Number(topic.hotScore) || 0)
      }));
      this.setData({ topics, loading: false });
    } catch (error) {
      this.setData({ loading: false, errorMessage: messageOf(error, '热榜加载失败，请重试') });
    }
  },
  retryLoad() {
    this.loadTopics();
  },
  // A failed summary stays next to the button; the list keeps showing.
  async summarize() {
    if (this.data.summarizing) return;
    this.setData({ summarizing: true, summaryError: '' });
    try {
      const result = await getHotTopicSummary();
      this.setData({ summary: result.answer || '', summarizing: false });
    } catch (error) {
      this.setData({ summarizing: false, summaryError: messageOf(error, '热榜总结失败，请重试') });
    }
  },
  openPost(event) {
    const postId = event.currentTarget.dataset.postId;
    if (postId) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${postId}` });
  }
});
