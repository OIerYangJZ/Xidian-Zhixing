import request from '../utils/request';
import { avatarInitial } from '../utils/format';
import { getData, toArray } from '../utils/format';

export const getConversations = async () => {
  const response = await request.get('/api/messages/conversations');
  return toArray(getData(response, [])).map((item) => {
    const name = String(item.name || item.peerName || '私信');
    return {
      ...item,
      id: String(item.id || ''),
      name,
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
  return getData(response, {});
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

// DM requests someone sent me; the pending ones wait for 同意 / 拒绝.
export const getDmRequests = async () => {
  const response = await request.get('/api/messages/requests');
  return toArray(getData(response, [])).map((item) => {
    const name = String(item.fromAlias || item.fromName || '匿名同学');
    return {
      ...item,
      id: String(item.id || item.requestId || ''),
      fromAlias: name,
      avatarInitial: avatarInitial(name),
      status: String(item.status || 'pending').toLowerCase()
    };
  });
};

export const handleDmRequest = async (requestId, accept) => {
  const action = accept ? 'accept' : 'reject';
  const response = await request.post(`/api/messages/requests/${requestId}/${action}`, {});
  return getData(response, {});
};
