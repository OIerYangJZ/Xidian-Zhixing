import {
  createCampusSchoolnetCaptcha,
  createDormWaterCaptcha,
  loginCampusIds,
  loginCampusPayment,
  loginCampusPhysics,
  loginCampusSchoolnet,
  loginCampusSport,
  loginDormWater,
  sendDormWaterSms
} from '../../../api/campus';
import { getUserInfo } from '../../../api/auth';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const STORAGE_KEY = 'campusAuthStates';

const SYSTEMS = [
  {
    id: 'ids',
    name: '统一认证',
    desc: '一站式、课表、成绩、考试等入口',
    tag: 'IDS',
    type: 'ids',
    passwordPlaceholder: '统一认证密码'
  },
  {
    id: 'payment',
    name: '缴费/水电',
    desc: '缴费平台和水电系统跳转验证',
    tag: '水电',
    type: 'ids',
    passwordPlaceholder: '统一认证密码'
  },
  {
    id: 'physics',
    name: '物理实验',
    desc: '物理实验选课与实验安排',
    tag: '实验',
    type: 'password',
    passwordPlaceholder: '物理实验密码'
  },
  {
    id: 'sport',
    name: '体育系统',
    desc: '体育课程、体测等系统访问',
    tag: '体育',
    type: 'password',
    passwordPlaceholder: '体育系统密码'
  },
  {
    id: 'schoolnet',
    name: '校园网自服务',
    desc: '校园网账号、查询密码和图形验证码',
    tag: '网络',
    type: 'schoolnet',
    passwordPlaceholder: '校园网查询密码'
  },
  {
    id: 'dormWater',
    name: '宿舍水机',
    desc: '手机号、图形验证码和短信验证码',
    tag: '水机',
    type: 'phone'
  }
];

const SYSTEM_MAP = SYSTEMS.reduce((map, item) => {
  map[item.id] = item;
  return map;
}, {});

const maskText = (value = '') => {
  const text = String(value || '');
  if (text.length <= 4) return text;
  return `${text.slice(0, 2)}****${text.slice(-2)}`;
};

const nowText = () => {
  const date = new Date();
  const pad = (value) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
};

const errorMessage = (error, fallback = '操作失败，请稍后重试') => {
  return (error && error.data && error.data.message)
    || (error && error.message)
    || fallback;
};

const resultRows = (result = {}) => {
  const rows = [];
  Object.keys(result || {}).forEach((key) => {
    const value = result[key];
    if (value === undefined || value === null || value === '' || key === 'message') return;
    if (typeof value === 'object') {
      rows.push({ key, value: JSON.stringify(value) });
      return;
    }
    rows.push({ key, value: String(value) });
  });
  return rows;
};

const buildSystemCards = (states = {}) => {
  return SYSTEMS.map((item) => ({
    ...item,
    verified: Boolean(states[item.id])
  }));
};

Page({
  data: {
    systems: buildSystemCards({}),
    activeSystem: 'ids',
    activeInfo: SYSTEMS[0],
    studentId: '',
    password: '',
    schoolnetCaptcha: '',
    schoolnetAttemptId: '',
    schoolnetImageSrc: '',
    dormWaterPhone: '',
    dormWaterImageCode: '',
    dormWaterSmsCode: '',
    dormWaterSessionId: '',
    dormWaterImageSrc: '',
    submitting: false,
    captchaLoading: false,
    smsSending: false,
    authStates: {},
    activeState: null,
    resultMessage: '',
    resultRows: [],
    themeClass: ''
  },

  onLoad(options) {
    const system = SYSTEM_MAP[options.system] ? options.system : 'ids';
    this.setActiveSystem(system);
    this.loadAuthStates();
    this.loadStudentId();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  async loadStudentId() {
    if (!wx.getStorageSync('token')) return;
    try {
      const response = await getUserInfo();
      const user = response.data || {};
      const studentId = user.studentId || String(user.email || '').split('@')[0] || '';
      if (studentId) this.setData({ studentId });
    } catch (error) {
      console.error(error);
    }
  },

  loadAuthStates() {
    const states = wx.getStorageSync(STORAGE_KEY) || {};
    this.setData({
      authStates: states,
      activeState: states[this.data.activeSystem] || null,
      systems: buildSystemCards(states)
    });
  },

  persistAuthState(systemId, result) {
    const current = wx.getStorageSync(STORAGE_KEY) || {};
    const state = {
      system: systemId,
      status: 'authenticated',
      studentId: result && result.studentId ? maskText(result.studentId) : '',
      message: (result && result.message) || '验证通过',
      updatedAt: nowText()
    };
    const next = {
      ...current,
      [systemId]: state
    };
    wx.setStorageSync(STORAGE_KEY, next);
    this.setData({
      authStates: next,
      activeState: next[this.data.activeSystem] || null,
      systems: buildSystemCards(next)
    });
  },

  setActiveSystem(systemId) {
    const info = SYSTEM_MAP[systemId] || SYSTEMS[0];
    this.setData({
      activeSystem: info.id,
      activeInfo: info,
      activeState: this.data.authStates[info.id] || null,
      password: '',
      schoolnetCaptcha: '',
      dormWaterImageCode: '',
      dormWaterSmsCode: '',
      resultMessage: '',
      resultRows: []
    });
    wx.setNavigationBarTitle({ title: info.name });
    if (info.id === 'schoolnet' && this.data.studentId && !this.data.schoolnetAttemptId) {
      this.refreshSchoolnetCaptcha();
    }
    if (info.id === 'dormWater' && !this.data.dormWaterSessionId) {
      this.refreshDormWaterCaptcha();
    }
  },

  switchSystem(event) {
    const systemId = event.currentTarget.dataset.system;
    if (!systemId || systemId === this.data.activeSystem) return;
    this.setActiveSystem(systemId);
  },

  onStudentIdInput(event) {
    this.setData({ studentId: event.detail.value });
  },

  onPasswordInput(event) {
    this.setData({ password: event.detail.value });
  },

  onSchoolnetCaptchaInput(event) {
    this.setData({ schoolnetCaptcha: event.detail.value });
  },

  onDormWaterPhoneInput(event) {
    this.setData({ dormWaterPhone: event.detail.value });
  },

  onDormWaterImageCodeInput(event) {
    this.setData({ dormWaterImageCode: event.detail.value });
  },

  onDormWaterSmsCodeInput(event) {
    this.setData({ dormWaterSmsCode: event.detail.value });
  },

  requireStudentAndPassword(label) {
    if (!this.data.studentId) {
      wx.showToast({ title: '请输入学号', icon: 'none' });
      return false;
    }
    if (!this.data.password) {
      wx.showToast({ title: `请输入${label}`, icon: 'none' });
      return false;
    }
    return true;
  },

  showResult(systemId, result) {
    const display = {
      ...result,
      studentId: result && result.studentId ? maskText(result.studentId) : ''
    };
    this.persistAuthState(systemId, result || {});
    this.setData({
      resultMessage: (result && result.message) || '验证通过',
      resultRows: resultRows(display)
    });
    if (systemId === 'ids') {
      wx.setStorageSync('campusScheduleUpdatedAt', Date.now());
    }
    wx.showToast({ title: '验证通过', icon: 'success' });
  },

  showError(error, fallback) {
    const message = errorMessage(error, fallback);
    this.setData({
      resultMessage: message,
      resultRows: []
    });
    wx.showToast({ title: message, icon: 'none' });
  },

  async submitPasswordAuth() {
    if (this.data.submitting) return;
    const { activeSystem, studentId, password } = this.data;
    const labels = {
      ids: '统一认证密码',
      payment: '统一认证密码',
      physics: '物理实验密码',
      sport: '体育系统密码'
    };
    if (!this.requireStudentAndPassword(labels[activeSystem] || '密码')) return;

    const actions = {
      ids: loginCampusIds,
      payment: loginCampusPayment,
      physics: loginCampusPhysics,
      sport: loginCampusSport
    };
    const action = actions[activeSystem];
    if (!action) return;

    this.setData({ submitting: true, resultMessage: '', resultRows: [] });
    wx.showLoading({ title: '正在验证' });
    try {
      const response = await action(studentId, password);
      wx.hideLoading();
      this.showResult(activeSystem, response.data || response || {});
    } catch (error) {
      wx.hideLoading();
      console.error(error);
      this.showError(error, `${SYSTEM_MAP[activeSystem].name}验证失败`);
    } finally {
      this.setData({ submitting: false, password: '' });
    }
  },

  async refreshSchoolnetCaptcha() {
    if (this.data.captchaLoading) return;
    if (!this.data.studentId) {
      wx.showToast({ title: '请输入学号后获取验证码', icon: 'none' });
      return;
    }
    this.setData({ captchaLoading: true, schoolnetCaptcha: '', resultMessage: '', resultRows: [] });
    try {
      const response = await createCampusSchoolnetCaptcha(this.data.studentId);
      const data = response.data || response || {};
      this.setData({
        schoolnetAttemptId: data.attemptId || '',
        schoolnetImageSrc: `data:${data.imageContentType || 'image/png'};base64,${data.imageBase64 || ''}`
      });
    } catch (error) {
      console.error(error);
      this.showError(error, '校园网验证码获取失败');
    } finally {
      this.setData({ captchaLoading: false });
    }
  },

  async submitSchoolnetAuth() {
    if (this.data.submitting) return;
    const { studentId, password, schoolnetCaptcha, schoolnetAttemptId } = this.data;
    if (!this.requireStudentAndPassword('校园网查询密码')) return;
    if (!schoolnetAttemptId || !schoolnetCaptcha) {
      wx.showToast({ title: '请先获取并填写验证码', icon: 'none' });
      return;
    }

    this.setData({ submitting: true, resultMessage: '', resultRows: [] });
    wx.showLoading({ title: '正在登录' });
    try {
      const response = await loginCampusSchoolnet(schoolnetAttemptId, studentId, password, schoolnetCaptcha);
      wx.hideLoading();
      this.showResult('schoolnet', response.data || response || {});
    } catch (error) {
      wx.hideLoading();
      console.error(error);
      this.showError(error, '校园网自服务登录失败');
      this.refreshSchoolnetCaptcha();
    } finally {
      this.setData({ submitting: false, password: '', schoolnetCaptcha: '' });
    }
  },

  async refreshDormWaterCaptcha() {
    if (this.data.captchaLoading) return;
    this.setData({ captchaLoading: true, dormWaterImageCode: '', resultMessage: '', resultRows: [] });
    try {
      const response = await createDormWaterCaptcha();
      const data = response.data || response || {};
      this.setData({
        dormWaterSessionId: data.sessionId || '',
        dormWaterImageSrc: `data:${data.imageContentType || 'image/png'};base64,${data.imageBase64 || ''}`
      });
    } catch (error) {
      console.error(error);
      this.showError(error, '宿舍水机验证码获取失败');
    } finally {
      this.setData({ captchaLoading: false });
    }
  },

  async sendDormWaterCode() {
    const { dormWaterSessionId, dormWaterPhone, dormWaterImageCode } = this.data;
    if (!dormWaterPhone) {
      wx.showToast({ title: '请输入手机号', icon: 'none' });
      return;
    }
    if (!dormWaterSessionId || !dormWaterImageCode) {
      wx.showToast({ title: '请先填写图形验证码', icon: 'none' });
      return;
    }
    this.setData({ smsSending: true, resultMessage: '', resultRows: [] });
    try {
      const response = await sendDormWaterSms(dormWaterSessionId, dormWaterPhone, dormWaterImageCode);
      this.setData({
        resultMessage: (response.data && response.data.message) || response.message || '短信已发送',
        resultRows: resultRows(response.data || response || {})
      });
      wx.showToast({ title: '短信已发送', icon: 'success' });
    } catch (error) {
      console.error(error);
      this.showError(error, '短信验证码发送失败');
      this.refreshDormWaterCaptcha();
    } finally {
      this.setData({ smsSending: false });
    }
  },

  async submitDormWaterAuth() {
    if (this.data.submitting) return;
    const { dormWaterPhone, dormWaterSmsCode } = this.data;
    if (!dormWaterPhone || !dormWaterSmsCode) {
      wx.showToast({ title: '请输入手机号和短信验证码', icon: 'none' });
      return;
    }
    this.setData({ submitting: true, resultMessage: '', resultRows: [] });
    wx.showLoading({ title: '正在登录' });
    try {
      const response = await loginDormWater(dormWaterPhone, dormWaterSmsCode);
      wx.hideLoading();
      this.showResult('dormWater', response.data || response || {});
    } catch (error) {
      wx.hideLoading();
      console.error(error);
      this.showError(error, '宿舍水机登录失败');
    } finally {
      this.setData({ submitting: false, dormWaterSmsCode: '' });
    }
  },

  clearCurrentState() {
    const { activeSystem } = this.data;
    const states = wx.getStorageSync(STORAGE_KEY) || {};
    delete states[activeSystem];
    wx.setStorageSync(STORAGE_KEY, states);
    this.setData({
      authStates: states,
      activeState: states[activeSystem] || null,
      systems: buildSystemCards(states),
      resultMessage: '已清除本地验证状态',
      resultRows: []
    });
  }
});
