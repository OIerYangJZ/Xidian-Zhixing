import request from '../utils/request';
import { getData, normalizePost, toArray } from '../utils/format';

export const getClubs = async () => {
  const response = await request.get('/api/clubs');
  return toArray(getData(response, []));
};

export const getClubDetail = async (id) => {
  const response = await request.get(`/api/clubs/${id}`);
  const club = getData(response, {});
  return {
    ...club,
    posts: toArray(club.posts).map(normalizePost)
  };
};

export const submitClubApplication = async (payload) => {
  const response = await request.post('/api/clubs/applications', payload);
  return getData(response, {});
};

export const getMyClubApplications = async () => {
  const response = await request.get('/api/clubs/applications/mine');
  return toArray(getData(response, []));
};
