import { enterPage } from '../../../utils/motion';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { settingsText } from '../../../utils/settings_copy';

const ITEMS = [
  ['user-agreement','用户协议','Terms of service'],
  ['privacy-policy','隐私政策','Privacy policy'],
  ['community-guidelines','社区规范','Community guidelines'],
  ['report-guidelines','举报说明','Reporting'],
  ['acknowledgements','致谢','Acknowledgements']
];
Page({
  data:{version:'',c:{},items:[]},
  onLoad() {
    const {miniProgram} = wx.getAccountInfoSync();
    const environments = {develop:'开发版',trial:'体验版'};
    this.setData({version:miniProgram.version || environments[miniProgram.envVersion] || miniProgram.envVersion});
  },
  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
    this.setData({c:settingsText(this.data.currentLanguage),items:ITEMS.map(([type,zh,en])=>({type,label:this.data.currentLanguage === 'en' ? en : zh}))});
  },
  openLegal(event) {
    const type = event.currentTarget.dataset.type;
    if (ITEMS.some(item=>item[0] === type)) wx.navigateTo({url:'/pages/profile/legal/index?type='+type});
  }
});
