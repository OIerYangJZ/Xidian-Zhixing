const loadLocalConfig = () => {
  try {
    if (typeof require !== 'function') {
      return {};
    }
    const localModule = require('./env.local');
    return localModule.default || localModule.localConfig || localModule || {};
  } catch (error) {
    const message = String((error && error.message) || '');
    if (/env\.local/.test(message) && /Cannot find module|not found|not defined|找不到|不存在/.test(message)) {
      return {};
    }
    throw error;
  }
};

const LOCAL_CONFIG = loadLocalConfig();
const ENV = LOCAL_CONFIG.env || 'auto'; // 'auto' | 'devtools' | 'lan' | 'prod'

const CONFIG = {
  devtools: {
    name: 'devtools',
    baseUrl: LOCAL_CONFIG.devtoolsBaseUrl || 'http://localhost:8080',
  },
  lan: {
    name: 'lan',
    baseUrl: LOCAL_CONFIG.lanBaseUrl,
  },
  prod: {
    name: 'prod',
    // The production site; env.local.js may point elsewhere (a staging host).
    baseUrl: LOCAL_CONFIG.prodBaseUrl || 'https://zhixing.xidian.edu.cn',
  }
};

// 体验版 (trial) and 正式版 (release) always talk to production, whatever
// env.local.js says: an upload made with a development config would
// otherwise ship pointing at a LAN address.
const miniProgramEnvVersion = () => {
  try {
    if (typeof wx !== 'undefined' && wx.getAccountInfoSync) {
      return String(wx.getAccountInfoSync().miniProgram.envVersion || '');
    }
  } catch (error) {}
  return '';
};

const getRuntimePlatform = () => {
  try {
    if (typeof wx !== 'undefined' && wx.getDeviceInfo) {
      return String(wx.getDeviceInfo().platform || '').toLowerCase();
    }
    if (typeof wx !== 'undefined' && wx.getAppBaseInfo) {
      const info = wx.getAppBaseInfo();
      return String(info.platform || '').toLowerCase();
    }
  } catch (error) {}
  return '';
};

const hasDevtoolsMarker = (info) => {
  if (!info || typeof info !== 'object') {
    return false;
  }
  const values = [
    info.platform,
    info.brand,
    info.model,
    info.system,
    info.environment,
    info.host && info.host.env,
    info.host && info.host.appId,
  ];
  return values.some((value) => /devtools/i.test(String(value || '')));
};

const isDevtoolsRuntime = () => {
  try {
    if (typeof __wxConfig !== 'undefined' && __wxConfig.platform === 'devtools') {
      return true;
    }
  } catch (error) {}
  try {
    if (typeof wx !== 'undefined' && wx.getWindowInfo && hasDevtoolsMarker(wx.getWindowInfo())) {
      return true;
    }
  } catch (error) {}
  try {
    if (typeof wx !== 'undefined' && wx.getDeviceInfo && hasDevtoolsMarker(wx.getDeviceInfo())) {
      return true;
    }
  } catch (error) {}
  try {
    if (typeof wx !== 'undefined' && wx.getAppBaseInfo && hasDevtoolsMarker(wx.getAppBaseInfo())) {
      return true;
    }
  } catch (error) {}
  return getRuntimePlatform() === 'devtools';
};

const resolveConfig = () => {
  let config;
  const envVersion = miniProgramEnvVersion();
  if (envVersion === 'trial' || envVersion === 'release') {
    config = CONFIG.prod;
  } else if (ENV === 'auto') {
    config = isDevtoolsRuntime() ? CONFIG.devtools : CONFIG.lan;
  } else {
    config = CONFIG[ENV];
  }
  if (!config) {
    throw new Error(`未知小程序环境：${ENV}`);
  }
  if (!config.baseUrl) {
    throw new Error(
      ENV === 'prod'
        ? '小程序生产 API 地址未配置：请在 env.local.js 中设置 prodBaseUrl'
        : '小程序本地后端地址未配置：请先运行 start_backend.bat 生成 miniprogram/config/env.local.js'
    );
  }
  return config;
};

export const envConfig = resolveConfig();
export const baseUrl = envConfig.baseUrl;
export const envName = envConfig === CONFIG.prod ? 'prod' : (ENV === 'auto' ? `auto:${envConfig.name}` : ENV);
