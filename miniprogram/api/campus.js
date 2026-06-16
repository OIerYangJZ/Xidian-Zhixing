import request from '../utils/request';

/**
 * 获取校园公告/新闻
 */
export const getAnnouncements = () => {
  return request.get('/api/announcements');
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

export const getCalendarSchedules = (params = {}) => {
  return request.get('/api/campus/schedules/calendar', params);
};

export const loginCampusIds = (identifier, password) => {
  return request.post('/api/campus/auth/ids', { identifier, password });
};

export const loginCampusPayment = (identifier, password) => {
  return request.post('/api/campus/auth/payment', { identifier, password });
};

export const loginCampusPhysics = (identifier, password) => {
  return request.post('/api/campus/auth/physics', { identifier, password });
};

export const loginCampusSport = (identifier, password) => {
  return request.post('/api/campus/auth/sport', { identifier, password });
};

export const createCampusSchoolnetCaptcha = (identifier) => {
  return request.post('/api/campus/auth/schoolnet/captcha', { identifier });
};

export const loginCampusSchoolnet = (attemptId, identifier, password, captcha) => {
  return request.post('/api/campus/auth/schoolnet/login', {
    attemptId,
    identifier,
    password,
    captcha
  });
};

export const createDormWaterCaptcha = () => {
  return request.post('/api/campus/auth/dorm-water/captcha', {});
};

export const sendDormWaterSms = (sessionId, phone, imageCode) => {
  return request.post('/api/campus/auth/dorm-water/sms', {
    sessionId,
    phone,
    imageCode
  });
};

export const loginDormWater = (phone, smsCode) => {
  return request.post('/api/campus/auth/dorm-water/login', {
    phone,
    smsCode
  });
};
