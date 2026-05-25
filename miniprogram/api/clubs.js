import request from '../utils/request';
import { getData, toArray } from '../utils/format';

export const getClubs = async () => {
  const response = await request.get('/api/clubs');
  return toArray(getData(response, []));
};

export const getClubDetail = async (id) => {
  const response = await request.get(`/api/clubs/${id}`);
  return getData(response, {});
};

export const submitClubApplication = async (payload) => {
  const response = await request.post('/api/clubs/applications', payload);
  return getData(response, {});
};

export const getMyClubApplications = async () => {
  const response = await request.get('/api/clubs/applications/mine');
  return toArray(getData(response, []));
};
