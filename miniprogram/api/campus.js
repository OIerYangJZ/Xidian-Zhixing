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

export const getCampusMaps = () => {
  return request.get('/api/campus/maps');
};

export const getCampusQuickLinks = () => {
  return request.get('/api/campus/quick-links');
};
