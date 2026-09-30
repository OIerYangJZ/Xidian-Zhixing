import { enterPage } from '../../../utils/motion';
import { getReportDetail } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const STATUS_TEXT = {
  pending: '待处理',
  resolved: '已处理',
  rejected: '已驳回',
  closed: '已关闭',
  misreport: '恶意举报'
};

Page({
  onShow() {
    enterPage(this);
    applyThemeAndLanguage(this);
  },
  data: {
    reportId: '',
    report: null,
    loading: true,
    errorMessage: ''
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    this.setData({ reportId: options.id || '' });
    if (this.data.reportId) {
      this.loadDetail();
    } else {
      this.setData({
        loading: false,
        errorMessage: '举报记录标识无效'
      });
    }
  },

  async loadDetail() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const report = await getReportDetail(this.data.reportId);
      this.setData({
        report: {
          ...report,
          statusText: STATUS_TEXT[report.status] || report.status || '待处理'
        },
        loading: false,
        errorMessage: ''
      });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: '举报详情加载失败，请重试'
      });
    }
  },

  openTarget() {
    const report = this.data.report;
    if (report && report.targetType === 'post' && report.targetId) {
      wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${report.targetId}` });
    }
  }
});
