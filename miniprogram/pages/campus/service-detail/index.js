import {
  createCampusSchoolnetCaptcha,
  createDormWaterCaptcha,
  getCalendarSchedules,
  getCampusServiceDetail,
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
import { openAppTarget } from '../../../utils/navigation';

const WEEKDAY_LABELS = ['一', '二', '三', '四', '五', '六', '日'];

const IDS_PAYMENT_SLUGS = new Set(['electricity', 'payment', 'drinking-water']);
const IDS_SERVICE_SLUGS = new Set([
  'ids-login',
  'classtable',
  'score',
  'exam',
  'empty-classroom',
  'attendance',
  'library',
  'school-card',
  'student-info',
  'leave',
  'repair',
  'space-reservation',
  'creative',
  'mobile-portal',
  'venue-reservation',
  'service-hall',
  'schedule-reminder'
]);

const buildCalendarDays = (calendar = {}) => {
  const days = Array.isArray(calendar.days) ? calendar.days : [];
  return days.map((day) => {
    const date = new Date(`${day.date}T00:00:00`);
    const dayIndex = date.getDay() === 0 ? 6 : date.getDay() - 1;
    return {
      ...day,
      label: WEEKDAY_LABELS[dayIndex] || '',
      shortDate: String(day.date || '').slice(5),
      items: Array.isArray(day.items) ? day.items : []
    };
  });
};

const authLabel = (authType = '') => {
  const labels = {
    ids: '统一认证',
    physicsPassword: '物理实验密码',
    sportPassword: '体育系统密码',
    schoolnetPassword: '校园网账号密码',
    phoneSms: '手机号短信',
    public: '无需登录',
    external: '外部入口'
  };
  return labels[authType] || authType || '未配置';
};

const maskText = (value = '') => {
  const text = String(value || '');
  if (text.length <= 4) return text;
  return `${text.slice(0, 2)}****${text.slice(-2)}`;
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

const errorMessage = (error, fallback = '操作失败，请稍后重试') => {
  return (error && error.data && error.data.message)
    || (error && error.message)
    || fallback;
};

const resolveAuthPanel = (service = {}) => {
  const slug = service.slug || '';
  const authType = service.authType || '';
  if (slug === 'schoolnet') return 'schoolnet';
  if (slug === 'dorm-water') return 'dormWater';
  if (slug === 'experiment' || authType === 'physicsPassword') return 'physics';
  if (slug === 'sport' || authType === 'sportPassword') return 'sport';
  if (IDS_PAYMENT_SLUGS.has(slug)) return 'payment';
  if (IDS_SERVICE_SLUGS.has(slug) || authType === 'ids') return 'ids';
  return '';
};

Page({
  data: {
    id: '',
    name: '',
    service: null,
    calendar: null,
    calendarDays: [],
    maps: [],
    loading: true,
    authPanel: '',
    authLabel: '',
    studentId: '',
    idsPassword: '',
    physicsPassword: '',
    sportPassword: '',
    schoolnetPassword: '',
    schoolnetCaptcha: '',
    schoolnetAttemptId: '',
    schoolnetImageSrc: '',
    dormWaterPhone: '',
    dormWaterImageCode: '',
    dormWaterSmsCode: '',
    dormWaterSessionId: '',
    dormWaterImageSrc: '',
    submittingAuth: false,
    captchaLoading: false,
    smsSending: false,
    authResult: null,
    authResultRows: [],
    authMessage: ''
  },

  onLoad(options) {
    const id = options.id || '';
    const name = decodeURIComponent(options.name || '');
    this.setData({ id, name });
    if (name) wx.setNavigationBarTitle({ title: name });
    this.loadData();
    this.loadUserInfo();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  async loadUserInfo() {
    try {
      const response = await getUserInfo();
      const user = response.data || {};
      const studentId = user.studentId || String(user.email || '').split('@')[0] || '';
      this.setData({ studentId });
      if (studentId && this.data.authPanel === 'schoolnet' && !this.data.schoolnetAttemptId) {
        this.refreshSchoolnetCaptcha();
      }
    } catch (error) {
      console.error(error);
    }
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const detailResponse = await getCampusServiceDetail(this.data.id);
      const service = detailResponse.data || detailResponse || {};
      const source = service.calendarSource || '';
      let calendar = null;
      let calendarDays = [];
      if (service.kind === 'schedule' || source) {
        const calendarData = await getCalendarSchedules({ source });
        calendar = calendarData.data || calendarData || {};
        calendarDays = buildCalendarDays(calendar);
      }
      const panel = resolveAuthPanel(service);
      wx.setNavigationBarTitle({ title: service.name || this.data.name || '校园服务' });
      this.setData({
        service: {
          ...service,
          authLabel: authLabel(service.authType)
        },
        name: service.name || this.data.name,
        calendar,
        calendarDays,
        maps: service.maps || [],
        authPanel: panel,
        authLabel: authLabel(service.authType),
        loading: false,
        authResult: null,
        authResultRows: [],
        authMessage: ''
      });
      if (panel === 'schoolnet' && this.data.studentId) this.refreshSchoolnetCaptcha();
      if (panel === 'dormWater') this.refreshDormWaterCaptcha();
    } catch (error) {
      console.error(error);
      this.setData({ loading: false });
    }
  },

  onStudentIdInput(event) {
    this.setData({ studentId: event.detail.value });
  },

  onIdsPasswordInput(event) {
    this.setData({ idsPassword: event.detail.value });
  },

  onPhysicsPasswordInput(event) {
    this.setData({ physicsPassword: event.detail.value });
  },

  onSportPasswordInput(event) {
    this.setData({ sportPassword: event.detail.value });
  },

  onSchoolnetPasswordInput(event) {
    this.setData({ schoolnetPassword: event.detail.value });
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

  ensureStudentAndPassword(password, label) {
    if (!this.data.studentId) {
      wx.showToast({ title: '请输入学号', icon: 'none' });
      return false;
    }
    if (!password) {
      wx.showToast({ title: `请输入${label}`, icon: 'none' });
      return false;
    }
    return true;
  },

  showAuthResult(result) {
    const displayResult = {
      ...result,
      studentId: result && result.studentId ? maskText(result.studentId) : result && result.studentId
    };
    this.setData({
      authResult: displayResult,
      authResultRows: resultRows(displayResult),
      authMessage: (result && result.message) || '验证完成'
    });
  },

  async reloadCalendar() {
    const service = this.data.service || {};
    const source = service.calendarSource || '';
    if (!(service.kind === 'schedule' || source)) return;
    const calendarData = await getCalendarSchedules({ source });
    const calendar = calendarData.data || calendarData || {};
    this.setData({
      calendar,
      calendarDays: buildCalendarDays(calendar)
    });
  },

  showAuthError(error, fallback) {
    const message = errorMessage(error, fallback);
    this.setData({
      authResult: null,
      authResultRows: [],
      authMessage: message
    });
    wx.showToast({ title: message, icon: 'none' });
  },

  async submitIdsAuth() {
    if (this.data.submittingAuth) return;
    const { studentId, idsPassword, authPanel } = this.data;
    if (!this.ensureStudentAndPassword(idsPassword, '统一认证密码')) return;
    this.setData({ submittingAuth: true, authMessage: '' });
    wx.showLoading({ title: '正在验证' });
    try {
      const response = authPanel === 'payment'
        ? await loginCampusPayment(studentId, idsPassword)
        : await loginCampusIds(studentId, idsPassword);
      wx.hideLoading();
      this.showAuthResult(response.data || response || {});
      wx.setStorageSync('campusScheduleUpdatedAt', Date.now());
      wx.showToast({ title: '验证通过', icon: 'success' });
      this.reloadCalendar().catch((error) => console.error(error));
    } catch (error) {
      wx.hideLoading();
      console.error(error);
      this.showAuthError(error, '统一认证验证失败');
    } finally {
      this.setData({ submittingAuth: false, idsPassword: '' });
    }
  },

  async submitPhysicsAuth() {
    if (this.data.submittingAuth) return;
    const { studentId, physicsPassword } = this.data;
    if (!this.ensureStudentAndPassword(physicsPassword, '物理实验密码')) return;
    this.setData({ submittingAuth: true, authMessage: '' });
    wx.showLoading({ title: '正在登录' });
    try {
      const response = await loginCampusPhysics(studentId, physicsPassword);
      wx.hideLoading();
      this.showAuthResult(response.data || response || {});
      wx.showToast({ title: '验证通过', icon: 'success' });
    } catch (error) {
      wx.hideLoading();
      console.error(error);
      this.showAuthError(error, '物理实验系统登录失败');
    } finally {
      this.setData({ submittingAuth: false, physicsPassword: '' });
    }
  },

  async submitSportAuth() {
    if (this.data.submittingAuth) return;
    const { studentId, sportPassword } = this.data;
    if (!this.ensureStudentAndPassword(sportPassword, '体育系统密码')) return;
    this.setData({ submittingAuth: true, authMessage: '' });
    wx.showLoading({ title: '正在登录' });
    try {
      const response = await loginCampusSport(studentId, sportPassword);
      wx.hideLoading();
      this.showAuthResult(response.data || response || {});
      wx.showToast({ title: '验证通过', icon: 'success' });
    } catch (error) {
      wx.hideLoading();
      console.error(error);
      this.showAuthError(error, '体育系统登录失败');
    } finally {
      this.setData({ submittingAuth: false, sportPassword: '' });
    }
  },

  async refreshSchoolnetCaptcha() {
    if (this.data.captchaLoading) return;
    if (!this.data.studentId) {
      wx.showToast({ title: '请输入学号后获取验证码', icon: 'none' });
      return;
    }
    this.setData({ captchaLoading: true, schoolnetCaptcha: '', authMessage: '' });
    try {
      const response = await createCampusSchoolnetCaptcha(this.data.studentId);
      const data = response.data || response || {};
      this.setData({
        schoolnetAttemptId: data.attemptId || '',
        schoolnetImageSrc: `data:${data.imageContentType || 'image/png'};base64,${data.imageBase64 || ''}`
      });
    } catch (error) {
      console.error(error);
      this.showAuthError(error, '校园网验证码获取失败');
    } finally {
      this.setData({ captchaLoading: false });
    }
  },

  async submitSchoolnetAuth() {
    if (this.data.submittingAuth) return;
    const {
      studentId,
      schoolnetPassword,
      schoolnetCaptcha,
      schoolnetAttemptId
    } = this.data;
    if (!this.ensureStudentAndPassword(schoolnetPassword, '校园网查询密码')) return;
    if (!schoolnetAttemptId || !schoolnetCaptcha) {
      wx.showToast({ title: '请先获取并填写验证码', icon: 'none' });
      return;
    }
    this.setData({ submittingAuth: true, authMessage: '' });
    wx.showLoading({ title: '正在登录' });
    try {
      const response = await loginCampusSchoolnet(
        schoolnetAttemptId,
        studentId,
        schoolnetPassword,
        schoolnetCaptcha
      );
      wx.hideLoading();
      this.showAuthResult(response.data || response || {});
      wx.showToast({ title: '验证通过', icon: 'success' });
    } catch (error) {
      wx.hideLoading();
      console.error(error);
      this.showAuthError(error, '校园网自服务登录失败');
      this.refreshSchoolnetCaptcha();
    } finally {
      this.setData({ submittingAuth: false, schoolnetPassword: '', schoolnetCaptcha: '' });
    }
  },

  async refreshDormWaterCaptcha() {
    if (this.data.captchaLoading) return;
    this.setData({ captchaLoading: true, dormWaterImageCode: '', authMessage: '' });
    try {
      const response = await createDormWaterCaptcha();
      const data = response.data || response || {};
      this.setData({
        dormWaterSessionId: data.sessionId || '',
        dormWaterImageSrc: `data:${data.imageContentType || 'image/png'};base64,${data.imageBase64 || ''}`
      });
    } catch (error) {
      console.error(error);
      this.showAuthError(error, '宿舍水机验证码获取失败');
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
    this.setData({ smsSending: true, authMessage: '' });
    try {
      const response = await sendDormWaterSms(dormWaterSessionId, dormWaterPhone, dormWaterImageCode);
      this.showAuthResult(response.data || response || {});
      wx.showToast({ title: '短信已发送', icon: 'success' });
    } catch (error) {
      console.error(error);
      this.showAuthError(error, '短信验证码发送失败');
      this.refreshDormWaterCaptcha();
    } finally {
      this.setData({ smsSending: false });
    }
  },

  async submitDormWaterAuth() {
    if (this.data.submittingAuth) return;
    const { dormWaterPhone, dormWaterSmsCode } = this.data;
    if (!dormWaterPhone || !dormWaterSmsCode) {
      wx.showToast({ title: '请输入手机号和短信验证码', icon: 'none' });
      return;
    }
    this.setData({ submittingAuth: true, authMessage: '' });
    wx.showLoading({ title: '正在登录' });
    try {
      const response = await loginDormWater(dormWaterPhone, dormWaterSmsCode);
      wx.hideLoading();
      this.showAuthResult(response.data || response || {});
      wx.showToast({ title: '验证通过', icon: 'success' });
    } catch (error) {
      wx.hideLoading();
      console.error(error);
      this.showAuthError(error, '宿舍水机登录失败');
    } finally {
      this.setData({ submittingAuth: false, dormWaterSmsCode: '' });
    }
  },

  openIdsLogin() {
    wx.navigateTo({ url: '/pages/campus/auth-center/index?system=ids' });
  },

  runAction(event) {
    const index = Number(event.currentTarget.dataset.index);
    const action = this.data.service && Array.isArray(this.data.service.actions)
      ? this.data.service.actions[index]
      : null;
    if (!action) return;

    if (action.type === 'calendar') {
      wx.pageScrollTo({ selector: '.calendar-section', duration: 180 });
      return;
    }
    if (action.type === 'map') {
      wx.navigateTo({ url: '/pages/campus/map/index' });
      return;
    }
    if (action.type === 'notice') {
      wx.showModal({
        title: '需要配置',
        content: this.data.service.requiredAccess || '该入口需要学校提供正式跳转配置后启用。',
        showCancel: false
      });
      return;
    }
    if (!openAppTarget(action)) {
      wx.showToast({ title: '暂未配置跳转地址', icon: 'none' });
    }
  },

  openMap() {
    wx.navigateTo({ url: '/pages/campus/map/index' });
  }
});
