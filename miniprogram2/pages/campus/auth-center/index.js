import { enterPage } from '../../../utils/motion';
import { createCampusSchoolnetCaptcha, createDormWaterCaptcha, loginCampusSchoolnet, loginDormWater, sendDormWaterSms } from '../../../api/campus';
import { getUserInfo } from '../../../api/auth';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { CAMPUS_AUTH_STATE_KEY } from '../../../utils/campus_auth';
import { formatTime } from '../../../utils/format';
import { settingsText } from '../../../utils/settings_copy';

const SYSTEMS = ['schoolnet','dormWater'];
const maskText = value => String(value).length > 4 ? String(value).slice(0,2)+'****'+String(value).slice(-2) : String(value);
Page({
  data:{c:{},activeSystem:'schoolnet',studentId:'',password:'',phone:'',imageCode:'',smsCode:'',captchaId:'',captchaSrc:'',captchaLoading:false,smsSending:false,smsSent:false,smsRemaining:0,submitting:false,authStates:{},activeState:null,resultMessage:'',errorMessage:'',profileError:'',loadingStudent:false,showPassword:false,clearingRecord:false},
  onLoad(options) {
    if (SYSTEMS.includes(options.system)) this.setData({activeSystem:options.system});
  },
  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
    this.setData({c:settingsText(this.data.currentLanguage)});
    if (!requireLoginPage()) return;
    const token = wx.getStorageSync('token');
    if (this._token !== token) {
      this._token = token;
      this._generation = (this._generation || 0) + 1;
      this._profileRequest = (this._profileRequest || 0) + 1;
      this._smsUntil = 0;
      clearInterval(this._smsTimer);
      this.setData({studentId:'',phone:'',password:'',imageCode:'',smsCode:'',captchaId:'',captchaSrc:'',captchaLoading:false,smsSending:false,smsSent:false,smsRemaining:0,submitting:false,clearingRecord:false,resultMessage:'',errorMessage:'',profileError:''});
      this.loadAuthStates();
      this.loadStudentId();
    }
    this.updateSmsCountdown();
    if (this.data.smsRemaining) this.startSmsTimer();
  },
  onHide() {
    clearInterval(this._smsTimer);
    this.setData({password:'',smsCode:'',showPassword:false});
  },
  onUnload() {
    this._generation = (this._generation || 0) + 1;
    this._profileRequest = (this._profileRequest || 0) + 1;
    clearInterval(this._smsTimer);
  },
  loadAuthStates() {
    const states = wx.getStorageSync(CAMPUS_AUTH_STATE_KEY) || {};
    this.setData({authStates:states,activeState:states[this.data.activeSystem] || null});
  },
  async loadStudentId() {
    const request = this._profileRequest = (this._profileRequest || 0) + 1;
    const token = wx.getStorageSync('token');
    this.setData({loadingStudent:true,profileError:''});
    try {
      const response = await getUserInfo();
      if (request !== this._profileRequest || token !== wx.getStorageSync('token')) return;
      if (!this.data.studentId && response.data.studentId) this.setData({studentId:response.data.studentId});
    } catch (error) {
      if (request === this._profileRequest && token === wx.getStorageSync('token')) this.setData({profileError:this.data.c.identityFailed});
    } finally {
      if (request === this._profileRequest) this.setData({loadingStudent:false});
    }
  },
  switchSystem(event) {
    const system = event.currentTarget.dataset.system;
    if (!SYSTEMS.includes(system) || system === this.data.activeSystem || this.data.submitting || this.data.smsSending || this.data.clearingRecord) return;
    this._generation = (this._generation || 0) + 1;
    this.setData({activeSystem:system,activeState:this.data.authStates[system] || null,password:'',imageCode:'',smsCode:'',captchaId:'',captchaSrc:'',captchaLoading:false,smsSent:false,resultMessage:'',errorMessage:'',showPassword:false});
  },
  onFieldInput(event) {
    const key = event.currentTarget.dataset.key;
    if (!['studentId','password','phone','imageCode','smsCode'].includes(key) || this.data.submitting || this.data.smsSending) return;
    const value = event.detail.value;
    const changes = {[key]:value,resultMessage:'',errorMessage:''};
    if (key === 'studentId' && value !== this.data.studentId) {
      this._profileRequest = (this._profileRequest || 0) + 1;
      this._generation = (this._generation || 0) + 1;
      Object.assign(changes,{captchaId:'',captchaSrc:'',imageCode:'',captchaLoading:false,loadingStudent:false});
    }
    if (key === 'phone' && value !== this.data.phone) Object.assign(changes,{smsCode:'',smsSent:false});
    this.setData(changes);
  },
  togglePassword() { this.setData({showPassword:!this.data.showPassword}); },
  async refreshCaptcha() {
    if (this.data.captchaLoading || this.data.submitting || this.data.smsSending) return;
    const {activeSystem,studentId} = this.data;
    if (activeSystem === 'schoolnet' && !studentId.trim()) {
      this.setData({errorMessage:this.data.c.accountRequired});
      return;
    }
    const generation = this._generation = (this._generation || 0) + 1;
    const token = wx.getStorageSync('token');
    this.setData({captchaLoading:true,captchaId:'',captchaSrc:'',imageCode:'',smsCode:'',smsSent:false,errorMessage:'',resultMessage:''});
    try {
      const response = activeSystem === 'schoolnet' ? await createCampusSchoolnetCaptcha(studentId.trim()) : await createDormWaterCaptcha();
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      const data = response.data;
      this.setData({captchaId:activeSystem === 'schoolnet' ? data.attemptId : data.sessionId,captchaSrc:'data:'+data.imageContentType+';base64,'+data.imageBase64});
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({errorMessage:error.data?.message || error.message || this.data.c.captchaFailed});
    } finally {
      if (generation === this._generation) this.setData({captchaLoading:false});
    }
  },
  updateSmsCountdown() {
    const remaining = Math.max(0,Math.ceil(((this._smsUntil || 0)-Date.now())/1000));
    this.setData({smsRemaining:remaining});
    if (!remaining) clearInterval(this._smsTimer);
  },
  startSmsTimer() {
    clearInterval(this._smsTimer);
    this.updateSmsCountdown();
    this._smsTimer = setInterval(()=>this.updateSmsCountdown(),1000);
  },
  async sendDormWaterCode() {
    if (this.data.activeSystem !== 'dormWater' || this.data.smsSending || this.data.submitting || this.data.captchaLoading || this.data.smsRemaining) return;
    const {phone,imageCode,captchaId} = this.data;
    if (!/^1\d{10}$/.test(phone.trim())) { this.setData({errorMessage:this.data.c.phoneInvalid}); return; }
    if (!captchaId || !imageCode.trim()) { this.setData({errorMessage:this.data.c.captchaRequired}); return; }
    const generation = this._generation;
    const token = wx.getStorageSync('token');
    this.setData({smsSending:true,errorMessage:'',resultMessage:''});
    try {
      await sendDormWaterSms(captchaId,phone.trim(),imageCode.trim());
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      this._smsUntil = Date.now()+60000;
      this.startSmsTimer();
      this.setData({smsSent:true,resultMessage:this.data.c.smsSent});
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({errorMessage:error.data?.message || error.message || this.data.c.smsFailed});
    } finally {
      if (generation === this._generation) this.setData({smsSending:false});
    }
  },
  async submitAuth() {
    if (this.data.submitting || this.data.captchaLoading || this.data.smsSending) return;
    const {activeSystem,studentId,password,phone,imageCode,smsCode,captchaId} = this.data;
    if (activeSystem === 'schoolnet' && (!studentId.trim() || !password || !captchaId || !imageCode.trim())) {
      this.setData({errorMessage:this.data.c.networkRequired}); return;
    }
    if (activeSystem === 'dormWater' && (!this.data.smsSent || !smsCode.trim())) {
      this.setData({errorMessage:this.data.c.smsRequired}); return;
    }
    const generation = this._generation;
    const token = wx.getStorageSync('token');
    this.setData({submitting:true,errorMessage:'',resultMessage:''});
    try {
      if (activeSystem === 'schoolnet') await loginCampusSchoolnet(captchaId,studentId.trim(),password,imageCode.trim());
      else await loginDormWater(captchaId,phone.trim(),smsCode.trim());
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      const state = {system:activeSystem,status:'authenticated',studentId:maskText(activeSystem === 'schoolnet' ? studentId.trim() : phone.trim()),updatedAt:formatTime(new Date().toISOString())};
      const states = {...this.data.authStates,[activeSystem]:state};
      try {
        wx.setStorageSync(CAMPUS_AUTH_STATE_KEY,states);
        this.setData({authStates:states,activeState:state,resultMessage:this.data.c.authSuccess});
      } catch (storageError) {
        this.setData({errorMessage:this.data.c.recordSaveFailed});
      }
      this.setData({captchaId:'',captchaSrc:'',imageCode:'',smsSent:false});
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({errorMessage:error.data?.message || error.message || this.data.c.authFailed});
    } finally {
      if (generation === this._generation) this.setData({submitting:false,password:'',smsCode:''});
    }
  },
  async clearCurrentState() {
    if (!this.data.activeState || this.data.submitting || this.data.smsSending || this.data.clearingRecord) return;
    const generation = this._generation;
    const token = wx.getStorageSync('token');
    this.setData({clearingRecord:true});
    try {
      const result = await wx.showModal({title:this.data.c.clearRecord,content:this.data.c.removeRecordCopy,confirmText:this.data.c.confirm,cancelText:this.data.c.cancel});
      if (!result.confirm || generation !== this._generation || token !== wx.getStorageSync('token')) return;
      const states = {...this.data.authStates};
      delete states[this.data.activeSystem];
      wx.setStorageSync(CAMPUS_AUTH_STATE_KEY,states);
      this.setData({authStates:states,activeState:null,resultMessage:'',errorMessage:''});
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({errorMessage:this.data.c.removeRecordFailed});
    } finally {
      if (generation === this._generation) this.setData({clearingRecord:false});
    }
  }
});
