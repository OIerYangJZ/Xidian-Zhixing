export const CAMPUS_AUTH_STATE_KEY = 'campusAuthStates';
export const CAMPUS_AUTH_SECRET_KEY = 'campusAuthSecrets';

export const getCampusAuthSecrets = () => wx.getStorageSync(CAMPUS_AUTH_SECRET_KEY) || {};

export const saveCampusAuthSecret = (systemId, payload) => {
  const current = getCampusAuthSecrets();
  const next = {
    ...current,
    [systemId]: {
      ...payload,
      updatedAt: Date.now()
    }
  };
  wx.setStorageSync(CAMPUS_AUTH_SECRET_KEY, next);
  return next;
};

export const removeCampusAuthSecret = (systemId) => {
  const current = getCampusAuthSecrets();
  delete current[systemId];
  wx.setStorageSync(CAMPUS_AUTH_SECRET_KEY, current);
  return current;
};
