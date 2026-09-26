import request from '../utils/request';
import { avatarInitial, getData, resolveUrl, toArray } from '../utils/format';

export const getConversations = async () => {
  const response = await request.get('/api/messages/conversations');
  return toArray(getData(response, [])).map((item) => {
    const name = String(item.name || item.peerName || '私信');
    return {
      ...item,
      id: String(item.id || ''),
      name,
      avatarUrl: resolveUrl(item.avatarUrl || ''),
      avatarInitial: avatarInitial(name)
    };
  });
};

export const getConversationMessages = async (conversationId) => {
  const response = await request.get(`/api/messages/conversations/${conversationId}/messages`);
  return toArray(getData(response, []));
};

export const createDirectConversation = async (payload) => {
  const response = await request.post('/api/messages/conversations/direct', payload);
  const conversation = getData(response, {});
  return { ...conversation, avatarUrl: resolveUrl(conversation.avatarUrl || '') };
};

export const sendConversationMessage = async (conversationId, payload) => {
  const response = await request.post(
    `/api/messages/conversations/${conversationId}/messages`,
    payload,
    { silentErrorToast: true }
  );
  return getData(response, {});
};

export const recallMessage = async (conversationId, messageId) => {
  const response = await request.delete(`/api/messages/messages/${messageId}/recall?conversationId=${encodeURIComponent(conversationId)}`, {});
  return getData(response, {});
};

export const deleteConversation = async (conversationId) => {
  const response = await request.delete(`/api/messages/conversations/${conversationId}`, {});
  return getData(response, {});
};

export const blockConversationPeer = async (conversationId) => {
  const response = await request.post(`/api/messages/conversations/${conversationId}/block`, {});
  return getData(response, {});
};

export const unblockConversationPeer = async (conversationId) => {
  const response = await request.post(`/api/messages/conversations/${conversationId}/unblock`, {});
  return getData(response, {});
};
