import { getHotTopics, getHotTopicSummary } from '../../../api/hot';

Page({
  data: {
    topics: [],
    summary: ''
  },
  async onLoad() {
    const topics = await getHotTopics();
    this.setData({ topics });
  },
  async summarize() {
    const result = await getHotTopicSummary();
    this.setData({ summary: result.answer || '' });
  },
  openPost(event) {
    const postId = event.currentTarget.dataset.postId;
    if (postId) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${postId}` });
  }
});
