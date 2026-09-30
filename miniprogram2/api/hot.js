import request from '../utils/request';
import { getData } from '../utils/format';

export const getHotTopics = async () => {
  const response = await request.get('/api/posts/trending', { limit: 100 });
  const payload = getData(response, {});
  const posts = Array.isArray(payload.items) ? payload.items : [];
  const topics = new Map();

  posts.forEach((post) => {
    const content = String(post.content || '');
    const tags = [...new Set(content.match(/#[^\s#]{1,30}/g) || [])];
    const postScore = Number(post.hotScore) || 0;
    const candidates = tags.length ? tags : [`post:${post.id}`];
    candidates.forEach((key) => {
      const topic = topics.get(key) || {
        id: key,
        postId: String(post.id),
        title: tags.length ? key : (content.slice(0, 36) || '校园新帖'),
        summary: content,
        sectionName: post.sectionName || '综合',
        hotScore: 0
      };
      topic.hotScore += postScore;
      topics.set(key, topic);
    });
  });

  return [...topics.values()]
    .sort((left, right) => right.hotScore - left.hotScore)
    .slice(0, 30)
    .map((topic, index) => ({ ...topic, rank: index + 1, hotScore: Math.round(topic.hotScore) }));
};

export const getHotTopicSummary = async () => { throw new Error('热榜 AI 总结尚未接入知行 AI 摘要接口'); };
