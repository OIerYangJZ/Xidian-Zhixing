Component({
  options:{multipleSlots:true},
  properties:{title:String,themeClass:String,english:Boolean,busy:Boolean,confirmLeaveMessage:String},
  data:{navTop:0,navHeight:32,navRight:100},
  lifetimes:{
    attached() {
      const {navTop,navHeight,navRight} = getApp().globalData;
      this.setData({navTop,navHeight,navRight});
    }
  },
  methods:{
    async goBack() {
      if (this.data.busy || this._leaving) return;
      this._leaving = true;
      try {
        if (this.data.confirmLeaveMessage) {
          const result = await wx.showModal({title:this.data.english ? 'Leave this page?' : '离开当前页面？',content:this.data.confirmLeaveMessage,confirmText:this.data.english ? 'Leave' : '离开',cancelText:this.data.english ? 'Stay' : '继续编辑'});
          if (!result.confirm || this.data.busy) return;
        }
        if (getCurrentPages().length > 1) await wx.navigateBack({delta:1});
        else await wx.switchTab({url:'/pages/treehole/index'});
      } catch (error) {
        wx.showToast({title:this.data.english ? 'Unable to go back. Try again.' : '返回失败，请重试。',icon:'none'});
      } finally { this._leaving = false; }
    }
  }
});
