import { enterPage } from '../../../utils/motion';
import { fetchAiModels } from '../../../api/ai';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { settingsText } from '../../../utils/settings_copy';

Page({
  data:{configured:false,model:'',models:[],loading:false,errorMessage:'',checked:false,c:{}},
  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
    this.setData({c:settingsText(this.data.currentLanguage)});
    if (!requireLoginPage()) return;
    this.refresh();
  },
  onUnload() { this._requestId = (this._requestId || 0) + 1; },
  async refresh() {
    const requestId = this._requestId = (this._requestId || 0) + 1;
    const token = wx.getStorageSync('token');
    this.setData({loading:true,errorMessage:'',checked:false,configured:false,model:'',models:[]});
    try {
      const status = await fetchAiModels();
      if (requestId !== this._requestId || token !== wx.getStorageSync('token')) return;
      this.setData({configured:status.configured,model:status.model,models:status.models,checked:true});
    } catch (error) {
      if (requestId === this._requestId && token === wx.getStorageSync('token')) this.setData({errorMessage:this.data.c.loadFailed});
    } finally {
      if (requestId === this._requestId) this.setData({loading:false});
    }
  }
});
