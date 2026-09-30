import request from '../utils/request';
import { avatarInitial, formatTime, getData, normalizePost, resolveUrl, toArray } from '../utils/format';
import { getCurrentUserId, getCurrentUser } from './session';

export const updateNotificationPreferences = async (payload) => {
  const response = await request.patch('/api/settings', { notifications: payload });
  return getData(response, {});
};

export const updateProfile = async (payload) => {
  const currentUser = await getCurrentUser();
  const userId = String(currentUser.id || '').trim();
  const unsupportedProfileFields = ['gender', 'college', 'major'];
  if (unsupportedProfileFields.some((key) => payload[key] && payload[key] !== currentUser[key])) {
    throw new Error('知行当前用户资料接口不支持修改性别、学院或专业');
  }
  const body = {
    username: payload.username || currentUser.username,
    name: payload.name || payload.nickname,
    bio: payload.bio || null,
    website: payload.website || null
  };
  if (payload.avatarUrl !== undefined || payload.backgroundImageUrl !== undefined) {
    throw new Error('知行当前用户资料接口暂不支持更换头像或封面');
  }
  Object.keys(body).forEach((key) => body[key] === undefined && delete body[key]);
  const response = await request.patch(`/api/users/${encodeURIComponent(userId)}`, body);
  const saved = getData(response, {});
  return {
    ...saved,
    ok: true,
    nickname: saved.name || body.name,
    gender: currentUser.gender || '',
    college: currentUser.college || '',
    major: currentUser.major || ''
  };
};

export const updatePrivacy = async (payload) => {
  const response = await request.patch('/api/settings', { privacy: payload });
  return getData(response, {});
};

export const submitCancellationRequest = async () => { throw new Error('知行当前后端未开放账号注销申请接口'); };

export const submitLevelUpgradeRequest = async () => { throw new Error('知行当前后端未开放等级升级申请接口'); };

export const getMyPosts = async () => {
  const userId = await getCurrentUserId();
  const response = await request.get(`/api/users/${encodeURIComponent(userId)}/posts`);
  return toArray(getData(response, [])).map(normalizePost);
};

export const getMyComments = async () => {
  const userId = await getCurrentUserId();
  const response = await request.get(`/api/users/${encodeURIComponent(userId)}/comments`);
  return toArray(getData(response, [])).map((comment) => ({
    ...comment,
    id: String(comment.id || ''),
    postId: String(comment.postId || ''),
    timeText: formatTime(comment.createdAt)
  }));
};

export const getMyReports = async () => {
  const userId = await getCurrentUserId();
  const response = await request.get(`/api/users/${encodeURIComponent(userId)}/reports`);
  return toArray(getData(response, []));
};

export const getReportDetail = async (reportId) => {
  const userId = await getCurrentUserId();
  const response = await request.get(`/api/users/${encodeURIComponent(userId)}/reports`, { id: reportId });
  const reports = toArray(getData(response, []));
  if (!reports.length) throw new Error('举报记录不存在');
  return reports[0];
};

export const getPublicUser = async (userId) => {
  const response = await request.get(`/api/users/${userId}`);
  const data = getData(response, {});
  const nickname = String(data.name || data.nickname || data.alias || '西电同学');
  data.id = String(data.id || userId);
  return {
    ...data,
    avatarInitial: avatarInitial(nickname),
    avatarUrl: resolveUrl(data.profilePhoto || data.avatarUrl || ''),
    backgroundImageUrl: resolveUrl(data.coverPhoto || data.backgroundImageUrl || '')
  };
};

export const searchUsers = async (keyword) => {
  const response = await request.get('/api/users', { search: keyword, limit: 30 });
  return toArray(getData(response, [])).map((item) => ({
    ...item,
    id: String(item.id || item.userId || ''),
    nickname: String(item.name || item.nickname || item.alias || '西电同学'),
    avatarInitial: avatarInitial(item.name || item.nickname || item.alias || '西电同学'),
    avatarUrl: resolveUrl(item.profilePhoto || item.avatarUrl || ''),
    backgroundImageUrl: resolveUrl(item.coverPhoto || item.backgroundImageUrl || '')
  }));
};

export const followUser = async (userId) => {
  const currentUserId = await getCurrentUserId();
  const response = await request.post(`/api/users/${encodeURIComponent(currentUserId)}/following`, { userIdToFollow: String(userId) });
  return getData(response, {});
};

export const unfollowUser = async (userId) => {
  const currentUserId = await getCurrentUserId();
  const response = await request.delete(`/api/users/${encodeURIComponent(currentUserId)}/following/${encodeURIComponent(userId)}`, {});
  return getData(response, {});
};

export const getFollowing = async () => {
  const currentUserId = await getCurrentUserId();
  const response = await request.get('/api/users', { 'followers-of': currentUserId, limit: 100 });
  return toArray(getData(response, [])).map((item) => ({
    ...item,
    id: String(item.id || item.userId || ''),
    nickname: String(item.name || item.nickname || item.alias || '西电同学'),
    avatarInitial: avatarInitial(item.name || item.nickname || item.alias || '西电同学'),
    avatarUrl: resolveUrl(item.profilePhoto || item.avatarUrl || '')
  }));
};

export const getFollowers = async () => {
  const currentUserId = await getCurrentUserId();
  const response = await request.get('/api/users', { 'following-of': currentUserId, limit: 100 });
  return toArray(getData(response, [])).map((item) => ({
    ...item,
    id: String(item.id || item.userId || ''),
    nickname: String(item.name || item.nickname || item.alias || '西电同学'),
    avatarInitial: avatarInitial(item.name || item.nickname || item.alias || '西电同学'),
    avatarUrl: resolveUrl(item.profilePhoto || item.avatarUrl || '')
  }));
};

export const getFriends = async () => { throw new Error('知行当前后端未提供好友列表接口'); };

export const submitFeedback = async () => { throw new Error('知行当前后端未开放反馈提交接口'); };

export const getMyFeedbacks = async () => { throw new Error('知行当前后端未开放我的反馈列表接口'); };

export const getBlocks = async () => {
  const currentUserId = await getCurrentUserId();
  const response = await request.get(`/api/users/${encodeURIComponent(currentUserId)}/blocks`);
  return toArray(getData(response, [])).map((item) => ({
    ...item,
    id: String(item.id || item.userId || ''),
    nickname: String(item.name || item.nickname || item.alias || '西电同学'),
    avatarInitial: avatarInitial(item.name || item.nickname || item.alias || '西电同学'),
    avatarUrl: resolveUrl(item.profilePhoto || item.avatarUrl || '')
  }));
};

export const blockUserGlobally = async (targetUserId) => {
  const currentUserId = await getCurrentUserId();
  const response = await request.post(`/api/users/${encodeURIComponent(currentUserId)}/blocks`, { blockedId: String(targetUserId) });
  return getData(response, {});
};

export const unblockUserGlobally = async (targetUserId) => {
  const currentUserId = await getCurrentUserId();
  const response = await request.delete(`/api/users/${encodeURIComponent(currentUserId)}/blocks/${encodeURIComponent(targetUserId)}`, {});
  return getData(response, {});
};
