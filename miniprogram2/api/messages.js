import request from '../utils/request';
import { avatarInitial, getData, resolveUrl, toArray } from '../utils/format';
import { getCurrentUserId } from './session';

export const getConversations = async () => {
  const response = await request.get('/api/messages');
  const conversations = toArray(getData(response, [])).map((item) => {
    const participant = item.participant || {};
    const name = String(participant.name || participant.username || item.name || '私信');
    return {
      ...item,
      id: String(item.id || ''),
      name,
      username: participant.username || '',
      peerId: String(participant.id || ''),
      avatarUrl: resolveUrl(participant.profilePhoto || ''),
      avatarInitial: avatarInitial(name),
      lastMessage: item.lastMessage || null
    };
  });
  const peerMap = wx.getStorageSync('zhixing-message-peers') || {};
  conversations.forEach(({ id, peerId }) => { if (id && peerId) peerMap[id] = peerId; });
  wx.setStorageSync('zhixing-message-peers', peerMap);
  return conversations;
};

export const getConversationMessages = async (conversationId) => {
  const response = await request.get(`/api/messages/${encodeURIComponent(conversationId)}`);
  const payload = getData(response, {});
  return toArray(payload.messages);
};

export const createDirectConversation = async (payload) => {
  let username = payload.username;
  if (!username && payload.targetUserId) {
    const profileResponse = await request.get(`/api/users/${encodeURIComponent(payload.targetUserId)}`);
    username = getData(profileResponse, {}).username;
  }
  if (!username) throw new Error('无法获取对方学号，暂时不能发起私信');
  const response = await request.post('/api/messages', { username });
  return getData(response, {});
};

export const sendConversationMessage = async (conversationId, payload) => {
  const response = await request.post(
    `/api/messages/${encodeURIComponent(conversationId)}/messages`,
    { content: payload.content },
    { silentErrorToast: true }
  );
  return getData(response, {});
};

export const recallMessage = async (conversationId, messageId) => {
  throw new Error('当前知行私信接口暂不支持撤回消息');
};

export const deleteConversation = async (conversationId) => {
  const response = await request.patch(`/api/messages/${encodeURIComponent(conversationId)}`, {});
  return getData(response, {});
};

export const blockConversationPeer = async (conversationId) => {
  const conversations = await getConversations();
  const peer = conversations.find((item) => item.id === String(conversationId));
  if (!peer || !peer.peerId) throw new Error('找不到私信对象');
  const userId = await getCurrentUserId();
  const response = await request.post(`/api/users/${encodeURIComponent(userId)}/blocks`, { blockedId: peer.peerId });
  return getData(response, {});
};

export const unblockConversationPeer = async (conversationId) => {
  const peers = wx.getStorageSync('zhixing-message-peers') || {};
  const peerId = peers[String(conversationId)];
  if (!peerId) throw new Error('找不到私信对象');
  const userId = await getCurrentUserId();
  const response = await request.delete(`/api/users/${encodeURIComponent(userId)}/blocks/${encodeURIComponent(peerId)}`, {});
  return getData(response, {});
};
