import { enterPage } from '../../../utils/motion';
import { getUserInfo } from '../../../api/auth';
import { uploadAvatarImage, uploadBackgroundImage } from '../../../api/uploads';
import { updateProfile } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { avatarInitial } from '../../../utils/format';
import { settingsText } from '../../../utils/settings_copy';

const FIELDS = ['nickname','bio','gender','college','major'];
Page({
  data:{loading:true,errorMessage:'',saving:false,uploadingAvatar:false,uploadingBackground:false,profile:null,form:{nickname:'',bio:'',gender:'',college:'',major:''},avatarPreview:'',backgroundPreview:'',avatarInitial:'',c:{},saveError:'',mediaError:'',mediaMessage:'',saved:false,dirty:false,genderIndex:0,genderOptions:['不填写','男','女']},
  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
    const c = settingsText(this.data.currentLanguage);
    this.setData({c,genderOptions:[c.noGender,c.male,c.female]});
    if (!requireLoginPage()) return;
    const token = wx.getStorageSync('token');
    if (this._token !== token) {
      this._token = token;
      this._generation = (this._generation || 0) + 1;
      this.setData({profile:null,form:{nickname:'',bio:'',gender:'',college:'',major:''},avatarPreview:'',backgroundPreview:'',dirty:false,saving:false,uploadingAvatar:false,uploadingBackground:false,mediaError:'',mediaMessage:'',saveError:'',saved:false});
    }
    if (!this.data.profile && !this.data.uploadingAvatar && !this.data.uploadingBackground) this.loadProfile();
  },
  onUnload() { this._generation = (this._generation || 0) + 1; },
  async loadProfile() {
    const generation = this._generation = (this._generation || 0) + 1;
    const token = wx.getStorageSync('token');
    this.setData({loading:true,errorMessage:''});
    try {
      const response = await getUserInfo();
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      const profile = response.data;
      if (!profile.id) throw new Error('Invalid profile');
      const form = {nickname:profile.nickname || profile.alias || '',bio:profile.bio || '',gender:profile.gender || '',college:profile.college || '',major:profile.major || ''};
      this._savedForm = {...form};
      this.setData({profile,form,avatarPreview:profile.avatarUrl || '',backgroundPreview:profile.backgroundImageUrl || '',avatarInitial:avatarInitial(form.nickname),genderIndex:['','男','女'].indexOf(form.gender),dirty:false,loading:false});
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({loading:false,errorMessage:this.data.c.loadFailed});
    }
  },
  updateForm(form) {
    this.setData({form,dirty:FIELDS.some(key=>form[key] !== this._savedForm[key]),saved:false,saveError:'',avatarInitial:avatarInitial(form.nickname)});
  },
  onFieldInput(event) {
    const key = event.currentTarget.dataset.key;
    if (FIELDS.includes(key) && !this.data.saving) this.updateForm({...this.data.form,[key]:event.detail.value});
  },
  onGenderChange(event) {
    if (this.data.saving) return;
    const index = Number(event.detail.value);
    if (![0,1,2].includes(index)) return;
    this.setData({genderIndex:index});
    this.updateForm({...this.data.form,gender:['','男','女'][index]});
  },
  chooseAvatar() { return this.chooseMedia('avatar'); },
  chooseBackground() { return this.chooseMedia('background'); },
  async chooseMedia(kind) {
    if (this.data.saving || this.data.uploadingAvatar || this.data.uploadingBackground || !this.data.profile) return;
    const flag = kind === 'avatar' ? 'uploadingAvatar' : 'uploadingBackground';
    const generation = this._generation;
    const token = wx.getStorageSync('token');
    this.setData({[flag]:true,mediaError:'',mediaMessage:''});
    let selected = false;
    try {
      const selection = await wx.chooseImage({count:1,sizeType:['compressed'],sourceType:['album','camera']});
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      selected = true;
      const file = selection.tempFilePaths[0];
      if (!file) throw new Error('No image selected');
      const upload = kind === 'avatar' ? await uploadAvatarImage(file) : await uploadBackgroundImage(file);
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      const url = kind === 'avatar' ? upload.avatarUrl : upload.url;
      if (!url) throw new Error('Invalid uploaded image');
      const profileField = kind === 'avatar' ? 'avatarUrl' : 'backgroundImageUrl';
      const profile = { ...this.data.profile, [profileField]: url };
      const currentUser = wx.getStorageSync('userInfo') || {};
      wx.setStorageSync('userInfo', { ...currentUser, [profileField]: url });
      this.setData({profile, [kind === 'avatar' ? 'avatarPreview' : 'backgroundPreview']:url,mediaMessage:kind === 'avatar' ? this.data.c.avatarSaved : this.data.c.coverSaved});
    } catch (error) {
      const cancelled = !selected && /cancel/.test(error.errMsg || '');
      if (!cancelled && generation === this._generation && token === wx.getStorageSync('token')) this.setData({mediaError:this.data.c.imageFailed});
    } finally {
      if (generation === this._generation) this.setData({[flag]:false});
    }
  },
  async clearBackground() {
    if (!this.data.backgroundPreview || this.data.uploadingBackground || this.data.uploadingAvatar || this.data.saving) return;
    const generation = this._generation;
    const token = wx.getStorageSync('token');
    this.setData({uploadingBackground:true,mediaError:'',mediaMessage:''});
    try {
      const confirmation = await wx.showModal({title:this.data.c.removeCoverConfirm,confirmText:this.data.c.remove,cancelText:this.data.c.cancel});
      if (!confirmation.confirm || generation !== this._generation || token !== wx.getStorageSync('token')) return;
      await updateProfile({backgroundImageUrl:''});
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      this.setData({backgroundPreview:'',mediaMessage:this.data.c.coverRemoved});
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({mediaError:this.data.c.removeCoverFailed});
    } finally {
      if (generation === this._generation) this.setData({uploadingBackground:false});
    }
  },
  async saveProfile() {
    if (!this.data.dirty || this.data.loading || this.data.saving || this.data.uploadingAvatar || this.data.uploadingBackground) return;
    const form = FIELDS.reduce((result,key)=>({...result,[key]:this.data.form[key].trim()}),{});
    if (form.bio.length > 100) { this.setData({saveError:this.data.c.bioTooLong}); return; }
    const generation = this._generation;
    const token = wx.getStorageSync('token');
    this.setData({saving:true,saveError:'',saved:false});
    try {
      const saved = await updateProfile(form);
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      if (!saved.ok || FIELDS.some(key=>typeof saved[key] !== 'string')) throw new Error('Invalid profile save response');
      const savedForm = FIELDS.reduce((result,key)=>({...result,[key]:saved[key]}),{});
      this._savedForm = {...savedForm};
      this.setData({form:savedForm,avatarInitial:avatarInitial(savedForm.nickname),dirty:false,saved:true});
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({saveError:this.data.c.submitFailed});
    } finally {
      if (generation === this._generation) this.setData({saving:false});
    }
  }
});
