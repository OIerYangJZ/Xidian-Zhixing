import request from '../utils/request';

const CAMPUS_AUTH_TIMEOUT = 60000;
const CAMPUS_AUTH_OPTIONS = {
  timeout: CAMPUS_AUTH_TIMEOUT,
  keepSessionOnUnauthorized: true
};

/**
 * 获取学院列表
 */
export const getColleges = () => {
  return request.get('/api/colleges');
};

export const getSections = () => {
  return request.get('/api/sections');
};

export const getSectionsTree = () => {
  return request.get('/api/sections/tree');
};

export const getCampusServices = () => {
  return request.get('/api/campus/services');
};

export const getCampusServiceDetail = (id) => {
  return request.get(`/api/campus/services/${id}`);
};

export const getCampusMaps = () => {
  return request.get('/api/campus/maps');
};

export const getCampusQuickLinks = () => {
  return request.get('/api/campus/quick-links');
};

export const getTodaySchedules = () => {
  return request.get('/api/campus/schedules/today');
};

const buildQuery = (params = {}) => {
  const query = Object.keys(params)
    .filter((key) => params[key] !== undefined && params[key] !== null && params[key] !== '')
    .map((key) => `${encodeURIComponent(key)}=${encodeURIComponent(params[key])}`)
    .join('&');
  return query ? `?${query}` : '';
};

export const getCalendarSchedules = (params = {}) => {
  return request.get(`/api/campus/schedules/calendar${buildQuery(params)}`);
};

export const loginCampusIds = (identifier, password, options = {}) => {
  return request.post('/api/campus/auth/ids', { identifier, password }, {
    ...CAMPUS_AUTH_OPTIONS,
    ...options
  });
};

export const loginCampusPayment = (identifier, password) => {
  return request.post('/api/campus/auth/payment', { identifier, password }, CAMPUS_AUTH_OPTIONS);
};

export const loginCampusPhysics = (identifier, password) => {
  return request.post('/api/campus/auth/physics', { identifier, password }, CAMPUS_AUTH_OPTIONS);
};

export const loginCampusSport = (identifier, password) => {
  return request.post('/api/campus/auth/sport', { identifier, password }, CAMPUS_AUTH_OPTIONS);
};

export const createCampusSchoolnetCaptcha = (identifier) => {
  return request.post('/api/campus/auth/schoolnet/captcha', { identifier }, CAMPUS_AUTH_OPTIONS);
};

export const loginCampusSchoolnet = (attemptId, identifier, password, captcha) => {
  return request.post('/api/campus/auth/schoolnet/login', {
    attemptId,
    identifier,
    password,
    captcha
  }, CAMPUS_AUTH_OPTIONS);
};

export const createDormWaterCaptcha = () => {
  return request.post('/api/campus/auth/dorm-water/captcha', {}, CAMPUS_AUTH_OPTIONS);
};

export const sendDormWaterSms = (sessionId, phone, imageCode) => {
  return request.post('/api/campus/auth/dorm-water/sms', {
    sessionId,
    phone,
    imageCode
  }, CAMPUS_AUTH_OPTIONS);
};

export const loginDormWater = (phone, smsCode) => {
  return request.post('/api/campus/auth/dorm-water/login', {
    phone,
    smsCode
  }, CAMPUS_AUTH_OPTIONS);
};
