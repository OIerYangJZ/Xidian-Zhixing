export const CAMPUS_AUTH_STATE_KEY = 'campusAuthStates';
export const CAMPUS_AUTH_SECRET_KEY = 'campusAuthSecrets';

export const clearLegacyCampusAuthSecrets = () => {
  wx.removeStorageSync(CAMPUS_AUTH_SECRET_KEY);
};

export const clearCampusAuthSession = () => {
  clearLegacyCampusAuthSecrets();
  wx.removeStorageSync(CAMPUS_AUTH_STATE_KEY);
  wx.removeStorageSync('campusScheduleUpdatedAt');
};
