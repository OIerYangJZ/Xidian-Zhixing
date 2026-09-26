import {
  createCampusSchoolnetCaptcha,
  createDormWaterCaptcha,
  loginCampusSchoolnet,
  loginDormWater,
  sendDormWaterSms
} from '../../../api/campus';
import { getUserInfo } from '../../../api/auth';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { CAMPUS_AUTH_STATE_KEY } from '../../../utils/campus_auth';

const SYSTEMS = [
  {
    id: 'schoolnet',
    name: '校园网自服务',
    desc: '校园网账号、查询密码和图形验证码',
    tag: '网络',
    icon: 'wifi',
    type: 'schoolnet',
    passwordPlaceholder: '校园网查询密码'
  },
  {
    id: 'dormWater',
    name: '宿舍水机',
    desc: '手机号、图形验证码和短信验证码',
    tag: '水机',
    icon: 'building',
    type: 'phone'
  }
];

const SMS_COOLDOWN_SECONDS = 60;

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

const buildSystemCards = (states = {}) => {
  return SYSTEMS.map((item) => ({
    ...item,
    verified: Boolean(states[item.id])
  }));
};

Page({
  data: {
    systems: buildSystemCards({}),
    activeSystem: 'schoolnet',
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
    smsCountdown: 0,
    formError: '',
    authStates: {},
    activeState: null,
    resultMessage: '',
    themeClass: ''
  },

  onLoad(options) {
    const system = SYSTEM_MAP[options.system] ? options.system : 'schoolnet';
    this.setActiveSystem(system);
    this.loadAuthStates();
    this.loadStudentId();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  onUnload() {
    this.stopSmsCountdown();
  },

  async loadStudentId() {
    if (!wx.getStorageSync('token')) return;
    try {
      const response = await getUserInfo();
      const user = response.data || {};
      // The server signs in to the campus systems with the caller's own
      // verified student id and refuses any other.
      const studentId = user.studentId || '';
      if (!studentId || this.data.studentId) return;
      this.setData({ studentId });
      // The captcha needs the account, which only just arrived.
      if (this.data.activeSystem === 'schoolnet' && !this.data.schoolnetAttemptId) {
        this.refreshSchoolnetCaptcha();
      }
    } catch (error) {
      console.error(error);
    }
  },

  loadAuthStates() {
    const states = wx.getStorageSync(CAMPUS_AUTH_STATE_KEY) || {};
    this.setData({
      authStates: states,
      activeState: states[this.data.activeSystem] || null,
      systems: buildSystemCards(states)
    });
  },

  persistAuthState(systemId, result) {
    const current = wx.getStorageSync(CAMPUS_AUTH_STATE_KEY) || {};
    const state = {
      system: systemId,
      status: 'authenticated',
      studentId: result && result.studentId ? maskText(result.studentId) : '',
      updatedAt: nowText()
    };
    const next = {
      ...current,
      [systemId]: state
    };
    wx.setStorageSync(CAMPUS_AUTH_STATE_KEY, next);
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
      formError: ''
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
      wx.showToast({ title: '请先完成学号认证', icon: 'none' });
      return false;
    }
    if (!this.data.password) {
      wx.showToast({ title: `请输入${label}`, icon: 'none' });
      return false;
    }
    return true;
  },

  showResult(systemId, result) {
    this.persistAuthState(systemId, result || {});
  },

  showError(error, fallback) {
    // Inline, not a toast: upstream messages are often longer than a toast shows.
    this.setData({ formError: errorMessage(error, fallback) });
  },

  async refreshSchoolnetCaptcha() {
    if (this.data.captchaLoading) return;
    if (!this.data.studentId) {
      wx.showToast({ title: '请先完成学号认证后再获取验证码', icon: 'none' });
      return;
    }
    this.setData({ captchaLoading: true, schoolnetCaptcha: '', resultMessage: '' });
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

    this.setData({ submitting: true, resultMessage: '', formError: '' });
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
    this.setData({ captchaLoading: true, dormWaterImageCode: '', resultMessage: '' });
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
    if (this.data.smsSending || this.data.smsCountdown) return;
    const { dormWaterSessionId, dormWaterPhone, dormWaterImageCode } = this.data;
    if (!dormWaterPhone) {
      wx.showToast({ title: '请输入手机号', icon: 'none' });
      return;
    }
    if (!dormWaterSessionId || !dormWaterImageCode) {
      wx.showToast({ title: '请先填写图形验证码', icon: 'none' });
      return;
    }
    this.setData({ smsSending: true, resultMessage: '', formError: '' });
    try {
      await sendDormWaterSms(dormWaterSessionId, dormWaterPhone, dormWaterImageCode);
      wx.showToast({ title: '短信已发送', icon: 'success' });
      this.startSmsCountdown();
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
    const { dormWaterSessionId, dormWaterPhone, dormWaterSmsCode } = this.data;
    if (!dormWaterSessionId || !dormWaterPhone || !dormWaterSmsCode) {
      wx.showToast({ title: '请输入手机号和短信验证码', icon: 'none' });
      return;
    }
    this.setData({ submitting: true, resultMessage: '', formError: '' });
    wx.showLoading({ title: '正在登录' });
    try {
      const response = await loginDormWater(dormWaterSessionId, dormWaterPhone, dormWaterSmsCode);
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

  startSmsCountdown() {
    this.stopSmsCountdown();
    this.setData({ smsCountdown: SMS_COOLDOWN_SECONDS });
    this.smsTimer = setInterval(() => {
      const next = this.data.smsCountdown - 1;
      if (next <= 0) this.stopSmsCountdown();
      else this.setData({ smsCountdown: next });
    }, 1000);
  },

  stopSmsCountdown() {
    if (this.smsTimer) clearInterval(this.smsTimer);
    this.smsTimer = null;
    if (this.data.smsCountdown) this.setData({ smsCountdown: 0 });
  },

  clearCurrentState() {
    const { activeSystem } = this.data;
    const states = wx.getStorageSync(CAMPUS_AUTH_STATE_KEY) || {};
    delete states[activeSystem];
    wx.setStorageSync(CAMPUS_AUTH_STATE_KEY, states);
    this.setData({
      authStates: states,
      activeState: states[activeSystem] || null,
      systems: buildSystemCards(states),
      resultMessage: ''
    });
  }
});
