import request from '../utils/request';
import { getData, responseContractError } from '../utils/format';

const CAMPUS_AUTH_TIMEOUT = 60000;
const CAMPUS_AUTH_OPTIONS = {
  timeout: CAMPUS_AUTH_TIMEOUT,
  keepSessionOnUnauthorized: true
};

const requireFields = (data, fields, label) => {
  fields.forEach((field) => {
    const value = data[field];
    if (typeof value !== 'string' || value.trim() === '') {
      throw responseContractError(`${label}响应缺少 ${field}`);
    }
  });
};

const requireObjectResponse = (response, label, fields = []) => {
  const data = getData(response, {});
  requireFields(data, fields, label);
  return { ...response, data };
};

const requireArrayResponse = (response) => {
  const data = getData(response, []);
  return { ...response, data };
};

const requireAuthResponse = (response, systemId) => {
  const result = requireObjectResponse(response, '校园认证', ['system', 'status']);
  if (result.data.system !== systemId || result.data.status !== 'authenticated') {
    throw responseContractError('校园认证响应状态无效');
  }
  return result;
};

/**
 * 获取学院列表
 */
export const getColleges = async () => {
  return requireArrayResponse(await request.get('/api/colleges'));
};

export const getSections = async () => {
  return requireArrayResponse(await request.get('/api/sections'));
};

export const getSectionsTree = async () => {
  return requireObjectResponse(await request.get('/api/sections/tree'), '分区树');
};

export const getCampusServices = async () => {
  return requireArrayResponse(await request.get('/api/campus/services'));
};

export const getCampusServiceDetail = async (id) => {
  return requireObjectResponse(
    await request.get(`/api/campus/services/${id}`),
    '校园服务',
    ['id']
  );
};

export const getCampusMaps = async () => {
  return requireArrayResponse(await request.get('/api/campus/maps'));
};

export const getCampusQuickLinks = async () => {
  return requireArrayResponse(await request.get('/api/campus/quick-links'));
};

export const getTodaySchedules = async () => {
  const response = requireObjectResponse(
    await request.get('/api/campus/schedules/today'),
    '今日课表',
    ['date']
  );
  if (!Array.isArray(response.data.items)) {
    throw responseContractError('今日课表响应 items 不是数组');
  }
  return response;
};

const buildQuery = (params = {}) => {
  const query = Object.keys(params)
    .filter((key) => params[key] !== undefined && params[key] !== null && params[key] !== '')
    .map((key) => `${encodeURIComponent(key)}=${encodeURIComponent(params[key])}`)
    .join('&');
  return query ? `?${query}` : '';
};

export const getCalendarSchedules = async (params = {}) => {
  const response = requireObjectResponse(
    await request.get(`/api/campus/schedules/calendar${buildQuery(params)}`),
    '课表日历',
    ['startDate', 'endDate']
  );
  if (!Array.isArray(response.data.days)) {
    throw responseContractError('课表日历响应 days 不是数组');
  }
  return response;
};

export const loginCampusIds = async (identifier, password, options = {}) => {
  const response = await request.post('/api/campus/auth/ids', { identifier, password }, {
    ...CAMPUS_AUTH_OPTIONS,
    ...options
  });
  return requireAuthResponse(response, 'ids');
};

export const loginCampusPayment = async (identifier, password) => {
  const response = await request.post(
    '/api/campus/auth/payment',
    { identifier, password },
    CAMPUS_AUTH_OPTIONS
  );
  return requireAuthResponse(response, 'payment');
};

export const loginCampusPhysics = async (identifier, password) => {
  const response = await request.post(
    '/api/campus/auth/physics',
    { identifier, password },
    CAMPUS_AUTH_OPTIONS
  );
  return requireAuthResponse(response, 'physics');
};

export const loginCampusSport = async (identifier, password) => {
  const response = await request.post(
    '/api/campus/auth/sport',
    { identifier, password },
    CAMPUS_AUTH_OPTIONS
  );
  return requireAuthResponse(response, 'sport');
};

export const createCampusSchoolnetCaptcha = async (identifier) => {
  const response = await request.post(
    '/api/campus/auth/schoolnet/captcha',
    { identifier },
    CAMPUS_AUTH_OPTIONS
  );
  return requireObjectResponse(
    response,
    '校园网验证码',
    ['attemptId', 'imageBase64', 'imageContentType']
  );
};

export const loginCampusSchoolnet = async (attemptId, identifier, password, captcha) => {
  const response = await request.post('/api/campus/auth/schoolnet/login', {
    attemptId,
    identifier,
    password,
    captcha
  }, CAMPUS_AUTH_OPTIONS);
  return requireAuthResponse(response, 'schoolnet');
};

export const createDormWaterCaptcha = async () => {
  const response = await request.post(
    '/api/campus/auth/dorm-water/captcha',
    {},
    CAMPUS_AUTH_OPTIONS
  );
  return requireObjectResponse(
    response,
    '宿舍水机验证码',
    ['sessionId', 'imageBase64', 'imageContentType']
  );
};

export const sendDormWaterSms = async (sessionId, phone, imageCode) => {
  const response = await request.post('/api/campus/auth/dorm-water/sms', {
    sessionId,
    phone,
    imageCode
  }, CAMPUS_AUTH_OPTIONS);
  const result = requireObjectResponse(response, '宿舍水机短信', ['status']);
  if (result.data.status !== 'smsSent') {
    throw responseContractError('宿舍水机短信响应状态无效');
  }
  return result;
};

export const loginDormWater = async (sessionId, phone, smsCode) => {
  const response = await request.post('/api/campus/auth/dorm-water/login', {
    sessionId,
    phone,
    smsCode
  }, CAMPUS_AUTH_OPTIONS);
  return requireAuthResponse(response, 'dormWater');
};
