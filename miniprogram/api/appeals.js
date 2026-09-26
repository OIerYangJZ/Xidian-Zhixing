import request from '../utils/request';
import { getData, responseContractError } from '../utils/format';

// GET /api/appeals/mine: { appeal: {...} | null, banned, canSubmit, supportEmail }.
export const getMyLatestAppeal = async () => {
  const response = await request.get('/api/appeals/mine', {}, { silentErrorToast: true });
  const data = getData(response, {});
  if (typeof data.banned !== 'boolean') {
    throw responseContractError('申诉状态响应缺少 banned');
  }
  if (typeof data.canSubmit !== 'boolean') {
    throw responseContractError('申诉状态响应缺少 canSubmit');
  }
  return data;
};

// The server checks the campus address against the session, so the caller
// passes the one this account signed in with.
export const submitUnbanAppeal = async ({ email, content }) => {
  const response = await request.post('/api/appeals', {
    email,
    appealType: 'ban_revoke',
    content
  }, { silentErrorToast: true });
  return getData(response, {});
};
