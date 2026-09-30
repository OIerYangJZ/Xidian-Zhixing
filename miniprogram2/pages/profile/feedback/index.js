import { enterPage } from '../../../utils/motion';
import { requireLoginPage } from '../../../utils/auth_guard';
import { getMyFeedbacks, submitFeedback } from '../../../api/user';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { formatTime } from '../../../utils/format';
import { settingsText } from '../../../utils/settings_copy';

const CATEGORIES = ['平台功能建议','学校服务意见','校园设施反馈','学校管理或流程建议','其他反馈'];
Page({
  data:{categories:CATEGORIES,categoryIndex:0,content:'',contact:'',records:[],loadingRecords:false,recordsError:'',submitting:false,submitError:'',submitted:false,tab:'new',c:{}},
  categoryLabels() {
    const c = this.data.c;
    return [c.platformFeedback,c.serviceFeedback,c.facilityFeedback,c.processFeedback,c.otherFeedback];
  },
  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
    this.setData({c:settingsText(this.data.currentLanguage)});
    this.setData({categories:this.categoryLabels()});
    if (!requireLoginPage()) return;
    const token = wx.getStorageSync('token');
    if (this._token !== token) {
      this._generation = (this._generation || 0) + 1;
      this._token = token;
      this.setData({content:'',contact:'',categoryIndex:0,records:[],recordsError:'',submitError:'',submitted:false,submitting:false,tab:'new'});
    }
    if (this.data.tab === 'records') this.loadRecords();
  },
  onUnload() { this._generation = (this._generation || 0) + 1; },
  onTabChange(event) {
    const tab = event.currentTarget.dataset.tab;
    if (this.data.submitting || !['new','records'].includes(tab) || tab === this.data.tab) return;
    this.setData({tab});
    if (tab === 'records') this.loadRecords();
  },
  async loadRecords() {
    const requestId = this._listRequest = (this._listRequest || 0) + 1;
    const generation = this._generation;
    const token = wx.getStorageSync('token');
    this.setData({loadingRecords:true,recordsError:''});
    try {
      const records = await getMyFeedbacks();
      if (generation !== this._generation || requestId !== this._listRequest || token !== wx.getStorageSync('token')) return;
      this.setData({records:records.map(item=>({...item,category:this.categoryLabels()[CATEGORIES.indexOf(item.category)] || item.category,timeText:formatTime(item.createdAt),statusText:item.status === 'resolved' ? this.data.c.feedbackReplied : item.status === 'closed' ? this.data.c.closed : this.data.c.feedbackPending})),loadingRecords:false});
    } catch (error) {
      if (generation === this._generation && requestId === this._listRequest && token === wx.getStorageSync('token')) this.setData({loadingRecords:false,recordsError:this.data.c.loadFailed});
    }
  },
  onContentInput(event) {
    if (!this.data.submitting) this.setData({content:event.detail.value,submitError:'',submitted:false});
  },
  onContactInput(event) {
    if (!this.data.submitting) this.setData({contact:event.detail.value});
  },
  onCategoryChange(event) {
    const index = Number(event.detail.value);
    if (!this.data.submitting && CATEGORIES[index]) this.setData({categoryIndex:index});
  },
  async submitFeedback() {
    if (this.data.submitting) return;
    const content = this.data.content.trim();
    if (!content) {
      this.setData({submitError:this.data.currentLanguage === 'en' ? 'Please describe your issue or suggestion.' : '请填写问题或建议。'});
      return;
    }
    const generation = this._generation;
    const token = wx.getStorageSync('token');
    this.setData({submitting:true,submitError:'',submitted:false});
    try {
      await submitFeedback({category:CATEGORIES[this.data.categoryIndex],content,contact:this.data.contact.trim()});
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      this.setData({content:'',contact:'',submitted:true,tab:'records'});
      this.loadRecords();
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({submitError:this.data.c.submitFailed});
    } finally {
      if (generation === this._generation) this.setData({submitting:false});
    }
  }
});
