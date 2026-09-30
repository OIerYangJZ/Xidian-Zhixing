import { enterPage } from '../../../utils/motion';
import { getUserInfo } from '../../../api/auth';
import { submitCancellationRequest, submitLevelUpgradeRequest } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { avatarInitial, formatTime } from '../../../utils/format';
import { settingsText } from '../../../utils/settings_copy';

Page({
  data: { loading:true, errorMessage:'', profile:null, c:{}, formType:'', reason:'', submitting:false, submitError:'', requests:[] },
  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
    this.setData({c:settingsText(this.data.currentLanguage)});
    if (!requireLoginPage()) return;
    if (this._token !== wx.getStorageSync('token')) {
      this._generation = (this._generation || 0) + 1;
      this._token = wx.getStorageSync('token');
      this.setData({profile:null,requests:[],formType:'',reason:'',submitting:false,submitError:''});
    }
    if (!this.data.submitting) this.loadProfile();
  },
  onUnload() { this._generation = (this._generation || 0) + 1; },
  setProfile(profile) {
    const c = this.data.c;
    const statusLabels = {pending:c.pending,approved:c.approved,rejected:c.rejected};
    this.setData({
      profile:{...profile,avatarInitial:avatarInitial(profile.nickname || profile.alias)},
      requests:[['upgrade',profile.levelUpgradeRequest],['cancellation',profile.accountCancellationRequest]]
        .filter(([,request])=>request).map(([type,request])=>({
          ...request,type,label:type === 'upgrade' ? c.upgrade : c.cancellation,
          statusText:statusLabels[request.status] || request.statusLabel || request.status,
          timeText:formatTime(request.createdAt),reviewNote:type === 'upgrade' ? request.adminNote : request.reviewNote
        }))
    });
  },
  async loadProfile() {
    const generation = this._generation = (this._generation || 0) + 1;
    const token = wx.getStorageSync('token');
    this.setData({loading:true,errorMessage:''});
    try {
      const response = await getUserInfo();
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      if (!response.data.id) throw new Error('Invalid profile');
      this.setProfile(response.data);
      this.setData({loading:false});
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({loading:false,errorMessage:this.data.c.loadFailed});
    }
  },
  editProfile() { wx.navigateTo({url:'/pages/profile/edit-profile/index'}); },
  openRequest(event) {
    const type = event.currentTarget.dataset.type;
    const profile = this.data.profile;
    if (!profile || this.data.submitting || !['upgrade','cancellation'].includes(type)) return;
    if (type === 'upgrade' && (profile.isLevelOneUser || profile.levelUpgradeRequest?.status === 'pending')) return;
    if (type === 'cancellation' && profile.accountCancellationRequest?.status === 'pending') return;
    this.setData({formType:type,reason:'',submitError:''});
  },
  closeRequest() {
    if (!this.data.submitting) this.setData({formType:'',reason:'',submitError:''});
  },
  onReasonInput(event) {
    if (!this.data.submitting) this.setData({reason:event.detail.value});
  },
  async submitRequest() {
    const {formType,reason,profile,c} = this.data;
    if (this.data.submitting || !profile || !['upgrade','cancellation'].includes(formType)) return;
    if (formType === 'upgrade' && (profile.isLevelOneUser || profile.levelUpgradeRequest?.status === 'pending')) return;
    if (formType === 'cancellation' && profile.accountCancellationRequest?.status === 'pending') return;
    const generation = this._generation;
    const token = wx.getStorageSync('token');
    this.setData({submitting:true,submitError:''});
    try {
      if (formType === 'cancellation') {
        const confirmation = await wx.showModal({title:c.cancellationConfirm,content:c.cancellationCopy,confirmText:c.submit,cancelText:c.cancel,confirmColor:'#d83c4c'});
        if (!confirmation.confirm || generation !== this._generation || token !== wx.getStorageSync('token')) return;
      }
      const submit = formType === 'upgrade' ? submitLevelUpgradeRequest : submitCancellationRequest;
      const request = await submit({reason:reason.trim()});
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      if (!request.id || !request.status) throw new Error('Invalid request response');
      this.setProfile({...this.data.profile,[formType === 'upgrade' ? 'levelUpgradeRequest' : 'accountCancellationRequest']:request});
      this.setData({formType:'',reason:''});
      wx.showToast({title:c.sent,icon:'success'});
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({submitError:c.submitFailed});
    } finally {
      if (generation === this._generation) this.setData({submitting:false});
    }
  }
});
