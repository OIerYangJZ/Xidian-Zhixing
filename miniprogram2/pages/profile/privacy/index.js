import { enterPage } from '../../../utils/motion';
import { getUserInfo } from '../../../api/auth';
import { updatePrivacy, updateNotificationPreferences } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { settingsText } from '../../../utils/settings_copy';

const GROUPS = [
  {id:'messages',title:'messages',rows:[['allowStrangerDm','receiveDm','receiveDmHint'],['showContactable','contact','contactHint']]},
  {id:'interactions',title:'interactions',rows:[['notifyComment','comment','commentHint'],['notifyReply','reply','replyHint'],['notifyLike','like','likeHint'],['notifyFavorite','favorite','favoriteHint']]},
  {id:'notices',title:'serviceNotices',rows:[['notifyReportResult','report','reportHint'],['notifySystem','systemNotice','systemNoticeHint']]}
];
const KEYS = GROUPS.reduce((keys,group)=>keys.concat(group.rows.map(row=>row[0])),[]);

Page({
  data: {loading:true,errorMessage:'',values:{},savingKeys:{},saveErrors:{},savedKeys:{},groups:[],c:{}},
  onLoad(options) { this._openNotifications = options.section === 'notifications'; },
  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
    const c = settingsText(this.data.currentLanguage);
    this.setData({c,groups:GROUPS.map(group=>({...group,label:c[group.title],rows:group.rows.map(([key,title,caption])=>({key,title:c[title],caption:c[caption]}))}))});
    if (!requireLoginPage()) return;
    const token = wx.getStorageSync('token');
    if (this._token !== token) {
      this._token = token;
      this._generation = (this._generation || 0) + 1;
      this._pending = 0;
      this._failedValues = {};
      this.setData({values:{},savingKeys:{},saveErrors:{},savedKeys:{}});
    }
    if (!this._pending) this.loadProfile();
  },
  onUnload() { this._generation = (this._generation || 0) + 1; },
  async loadProfile() {
    if (this._pending) return;
    const generation = this._generation = (this._generation || 0) + 1;
    const token = wx.getStorageSync('token');
    this.setData({loading:true,errorMessage:''});
    try {
      const response = await getUserInfo();
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      const values = {};
      for (const key of KEYS) {
        if (typeof response.data[key] !== 'boolean') throw new Error('Invalid preference: '+key);
        values[key] = response.data[key];
      }
      this._failedValues = {};
      this.setData({values,loading:false,savingKeys:{},saveErrors:{},savedKeys:{}},()=>{
        if (this._openNotifications) {
          this._openNotifications = false;
          wx.pageScrollTo({selector:'#settings-interactions',offsetTop:-(getApp().globalData.navTop+getApp().globalData.navHeight+12),duration:250});
        }
      });
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({loading:false,errorMessage:this.data.c.loadFailed});
    }
  },
  onSwitchChange(event) {
    this.savePreference(event.currentTarget.dataset.key,Boolean(event.detail.value));
  },
  retrySave(event) {
    const key = event.currentTarget.dataset.key;
    if (this._failedValues && typeof this._failedValues[key] === 'boolean') this.savePreference(key,this._failedValues[key]);
  },
  async savePreference(key,value) {
    if (!KEYS.includes(key) || this.data.loading || this.data.savingKeys[key] || typeof this.data.values[key] !== 'boolean') return;
    const previous = this.data.values[key];
    const generation = this._generation;
    const token = wx.getStorageSync('token');
    this._pending = (this._pending || 0) + 1;
    this.setData({values:{...this.data.values,[key]:value},savingKeys:{...this.data.savingKeys,[key]:true},saveErrors:{...this.data.saveErrors,[key]:''},savedKeys:{...this.data.savedKeys,[key]:false}});
    try {
      const save = key === 'allowStrangerDm' || key === 'showContactable' ? updatePrivacy : updateNotificationPreferences;
      await save({[key]:value});
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      if (this._failedValues) delete this._failedValues[key];
      this.setData({savedKeys:{...this.data.savedKeys,[key]:true}});
    } catch (error) {
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      this._failedValues = {...this._failedValues,[key]:value};
      this.setData({values:{...this.data.values,[key]:previous},saveErrors:{...this.data.saveErrors,[key]:this.data.c.saveFailed}});
    } finally {
      if (generation === this._generation && token === wx.getStorageSync('token')) {
        this._pending -= 1;
        this.setData({savingKeys:{...this.data.savingKeys,[key]:false}});
      }
    }
  },
  openBlocks() { wx.navigateTo({url:'/pages/profile/privacy/blocklist/index'}); }
});
