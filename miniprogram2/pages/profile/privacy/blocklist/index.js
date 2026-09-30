import { enterPage } from '../../../../utils/motion';
import { getBlocks, unblockUserGlobally } from '../../../../api/user';
import { requireLoginPage } from '../../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../../utils/theme_i18n';
import { settingsText } from '../../../../utils/settings_copy';

Page({
  data:{loading:true,blocks:[],errorMessage:'',pending:{},errors:{},c:{}},
  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
    this.setData({c:settingsText(this.data.currentLanguage)});
    if (!requireLoginPage()) return;
    this.loadBlocks();
  },
  onUnload() { this._generation = (this._generation || 0) + 1; },
  async loadBlocks() {
    const generation = this._generation = (this._generation || 0) + 1;
    const token = wx.getStorageSync('token');
    this.setData({loading:true,blocks:[],pending:{},errors:{},errorMessage:''});
    try {
      const blocks = await getBlocks();
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      this.setData({blocks,loading:false});
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({loading:false,errorMessage:this.data.c.loadFailed});
    }
  },
  async onUnblockTap(event) {
    const id = event.currentTarget.dataset.id;
    const account = this.data.blocks.find(item=>item.id === id);
    if (!account || this.data.pending[id]) return;
    const generation = this._generation;
    const token = wx.getStorageSync('token');
    this.setData({pending:{...this.data.pending,[id]:true},errors:{...this.data.errors,[id]:''}});
    try {
      const result = await wx.showModal({
        title:this.data.c.unblock,
        content:this.data.currentLanguage === 'en' ? 'Unblock '+account.nickname+'?' : '将 '+account.nickname+' 移出已屏蔽名单？',
        confirmText:this.data.c.confirm,cancelText:this.data.c.cancel
      });
      if (!result.confirm || generation !== this._generation || token !== wx.getStorageSync('token')) return;
      await unblockUserGlobally(id);
      if (generation !== this._generation || token !== wx.getStorageSync('token')) return;
      this.setData({blocks:this.data.blocks.filter(item=>item.id !== id)});
      wx.showToast({title:this.data.c.unblocked,icon:'success'});
    } catch (error) {
      if (generation === this._generation && token === wx.getStorageSync('token')) this.setData({errors:{...this.data.errors,[id]:this.data.currentLanguage === 'en' ? 'Unable to unblock. Try again.' : '解除失败，请重试。'}});
    } finally {
      if (generation === this._generation) this.setData({pending:{...this.data.pending,[id]:false}});
    }
  }
});
