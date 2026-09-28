import { baseUrl } from '../config/env';

const isRecord = (value) => {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
};

export const responseContractError = (message = '服务器响应格式错误') => {
  const error = new Error(message);
  error.data = { message };
  return error;
};

export const getData = (response, expectedShape = null) => {
  if (!isRecord(response) || !Object.prototype.hasOwnProperty.call(response, 'data')) {
    throw responseContractError('服务器响应缺少 data 字段');
  }
  const data = response.data;
  if (Array.isArray(expectedShape) && !Array.isArray(data)) {
    throw responseContractError('服务器响应 data 不是数组');
  }
  if (isRecord(expectedShape) && !isRecord(data)) {
    throw responseContractError('服务器响应 data 不是对象');
  }
  if (data === null || data === undefined) {
    throw responseContractError('服务器响应 data 为空');
  }
  return data;
};

export const toArray = (value) => {
  return Array.isArray(value) ? value : [];
};

export const truncate = (value, max = 80) => {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (text.length <= max) return text;
  return `${text.slice(0, max)}...`;
};

export const inlineTagSegments = (value) => {
  const text = String(value || '');
  const segments = [];
  const pattern = /#([^\s#]{1,30})(?=\s|$)/g;
  let cursor = 0;
  let match = pattern.exec(text);
  while (match) {
    if (match.index > cursor) {
      segments.push({ type: 'text', text: text.slice(cursor, match.index) });
    }
    segments.push({ type: 'tag', text: match[0], tag: match[1] });
    cursor = match.index + match[0].length;
    match = pattern.exec(text);
  }
  if (cursor < text.length) {
    segments.push({ type: 'text', text: text.slice(cursor) });
  }
  return segments;
};

export const formatTime = (value) => {
  const text = String(value || '').trim();
  const date = text ? new Date(text) : null;
  if (!date || Number.isNaN(date.getTime())) return '';

  const diff = Date.now() - date.getTime();
  const minute = 60 * 1000;
  const hour = 60 * minute;
  const day = 24 * hour;
  if (diff >= 0 && diff < 5 * minute) return 'now';
  if (diff >= 0 && diff < hour) return `${Math.floor(diff / minute)}min`;
  if (diff >= 0 && diff < day) return `${Math.floor(diff / hour)}h`;
  if (diff >= 0 && diff < 7 * day) {
    const days = Math.floor(diff / day);
    return `${days} ${days === 1 ? 'day' : 'days'}`;
  }

  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${months[date.getMonth()]} ${date.getDate()}, ${date.getFullYear()}`;
};

const SECTION_COLORS = {
  全部: '#8E8E93',
  综合: '#6B7FD7',
  学习交流: '#5E8FD4',
  二手交易: '#5EAF7C',
  找搭子: '#E09C5E',
  失物招领: '#D45E8A',
  吐槽日常: '#9B6ED4',
  求助问答: '#5EAAD4',
  活动拼车: '#E06C4E',
  找对象: '#D45E8A',
  交友扩列: '#5EC4AF',
  八卦吃瓜: '#9B6ED4',
  其他: '#6B7FD7'
};

// One of the six theme channel colours (--zx-channel-1…6), picked with the
// same hash as ZxTokens.channelFor on web and Android, so a section keeps
// its colour across clients.
export const sectionTone = (sectionName) => {
  const text = String(sectionName || '').trim();
  if (!text) return 1;
  let hash = 0;
  for (let i = 0; i < text.length; i += 1) {
    hash = (hash * 31 + text.charCodeAt(i)) & 0x7fffffff;
  }
  return (hash % 6) + 1;
};

export const sectionColor = (sectionName) => {
  return SECTION_COLORS[String(sectionName || '').trim()] || '#155E75';
};

export const avatarInitial = (value) => {
  const text = String(value || '').trim();
  if (!text) return '匿';
  return text.slice(0, 1);
};

export const resolveUrl = (value) => {
  const text = String(value || '').trim();
  if (!text) return '';
  if (/^https?:\/\//i.test(text)) return text;
  if (text.startsWith('/')) return `${baseUrl}${text}`;
  return `${baseUrl.replace(/\/$/, '')}/${text}`;
};

const statusLabel = (status) => {
  const value = String(status || '').toLowerCase();
  if (value === 'resolved') return '已解决';
  if (value === 'closed') return '已结束';
  return '进行中';
};

const normalizeCount = (raw, field, label) => {
  const value = raw[field];
  if (value === undefined || value === null) return 0;
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
    throw responseContractError(`${label} ${field} 无效`);
  }
  return value;
};

export const normalizePost = (raw = {}) => {
  if (!isRecord(raw)) {
    throw responseContractError('帖子数据格式错误');
  }
  const id = String(raw.id || raw.postId || '').trim();
  if (!id) {
    throw responseContractError('帖子数据缺少 ID');
  }
  const title = String(raw.title || '').trim();
  const content = String(raw.content || '').trim();
  const tags = toArray(raw.tags).map((item) => String(item || '').trim()).filter(Boolean);
  const rawImageUrls = toArray(raw.imageUrls);
  const sourceImageUrls = rawImageUrls.length ? rawImageUrls : toArray(raw.images);
  const imageUrls = sourceImageUrls.map(resolveUrl).filter(Boolean);
  const displayTitle = title || truncate(content, 24) || '无标题帖子';
  const summary = truncate(content, 96);
  const isAnonymous = Boolean(raw.isAnonymous || raw.useAnonymousAlias);
  const authorAlias = isAnonymous
    ? String(raw.authorAlias || raw.alias || raw.authorName || '匿名用户')
    : String(raw.authorAlias || raw.alias || raw.authorName || '匿名同学');
  const sectionName = String(raw.sectionName || '').trim();
  return {
    ...raw,
    id,
    title,
    titleSegments: inlineTagSegments(title),
    displayTitle,
    displayTitleSegments: inlineTagSegments(displayTitle),
    content,
    contentSegments: inlineTagSegments(content),
    summary,
    summarySegments: inlineTagSegments(summary),
    sectionName,
    sectionColor: sectionColor(sectionName),
    sectionTone: sectionTone(sectionName),
    tags,
    tagText: tags.join(' / '),
    authorAlias,
    authorInitial: isAnonymous ? '匿' : avatarInitial(authorAlias),
    authorAvatarUrl: isAnonymous ? '' : resolveUrl(raw.authorAvatarUrl || ''),
    isAnonymous,
    createdAt: raw.createdAt || '',
    timeText: formatTime(raw.createdAt),
    likeCount: normalizeCount(raw, 'likeCount', '帖子数据'),
    commentCount: normalizeCount(raw, 'commentCount', '帖子数据'),
    favoriteCount: normalizeCount(raw, 'favoriteCount', '帖子数据'),
    viewCount: normalizeCount(raw, 'viewCount', '帖子数据'),
    liked: Boolean(raw.liked || raw.isLiked),
    favorited: Boolean(raw.favorited || raw.isFavorited),
    isPinned: Boolean(raw.isPinned),
    // Only one's own posts come back pending / rejected (待审核 / 未通过审核).
    reviewStatus: String(raw.reviewStatus || 'approved'),
    statusLabel: statusLabel(raw.status),
    statusKey: ['resolved', 'closed'].includes(String(raw.status || '').toLowerCase())
      ? String(raw.status).toLowerCase()
      : 'ongoing',
    imageUrls,
    firstImageUrl: imageUrls[0] || ''
  };
};

export const normalizeComment = (raw = {}) => {
  if (!isRecord(raw)) {
    throw responseContractError('评论数据格式错误');
  }
  const id = String(raw.id || raw.commentId || '').trim();
  if (!id) {
    throw responseContractError('评论数据缺少 ID');
  }
  const authorAlias = String(raw.authorAlias || raw.authorName || '匿名同学');
  return {
    ...raw,
    id,
    content: String(raw.content || ''),
    authorAlias,
    authorInitial: avatarInitial(authorAlias),
    authorAvatarUrl: resolveUrl(raw.authorAvatarUrl || raw.authorAvatar || ''),
    timeText: formatTime(raw.createdAt),
    likeCount: normalizeCount(raw, 'likeCount', '评论数据'),
    liked: Boolean(raw.liked || raw.isLiked),
    parentId: String(raw.parentId || '')
  };
};

// What happened, as the Flutter client words it (NotificationItem.displayTitle):
// the server title is kept for report results and system notices.
const notificationAction = (type, relatedType, title) => {
  const t = String(type || '').trim().toLowerCase();
  const r = String(relatedType || '').trim().toLowerCase();
  const own = String(title || '').trim();
  switch (t) {
    case 'like':
      return r === 'comment' ? '喜欢了你的评论' : (r === 'post' ? '喜欢了你的帖子' : '喜欢了你的内容');
    case 'favorite':
      return (r === 'post' || !r) ? '收藏了你的帖子' : '收藏了你的内容';
    case 'repost':
      return '转发了你的帖子';
    case 'mention':
      return r === 'comment' ? '在评论中提到了你' : '在帖子中提到了你';
    case 'reply':
      return (r === 'comment' || !r) ? '回复了你的评论' : '回复了你的内容';
    case 'comment':
      if (r === 'comment') return '评论了你的评论';
      return (r === 'post' || !r) ? '评论了你的帖子' : '评论了你的内容';
    case 'report_result':
      return own || '举报结果';
    case 'system':
    case 'system_announcement':
      return own || '系统公告';
    default:
      return own || '通知';
  }
};

export const normalizeNotification = (raw = {}) => {
  if (!isRecord(raw)) {
    throw responseContractError('通知数据格式错误');
  }
  const id = String(raw.id || '').trim();
  if (!id) {
    throw responseContractError('通知数据缺少 ID');
  }
  return {
    ...raw,
    id,
    title: String(raw.title || '通知'),
    headline: [String(raw.actorAlias || '').trim(), notificationAction(raw.type || raw.notificationType, raw.relatedType, raw.title)]
      .filter(Boolean).join(' '),
    content: String(raw.content || ''),
    type: String(raw.type || raw.notificationType || ''),
    timeText: formatTime(raw.createdAt),
    isRead: Boolean(raw.isRead),
    actorAvatarUrl: resolveUrl(raw.actorAvatarUrl || '')
  };
};
