import {
  addTag,
  createKnowledgeSource,
  deleteKnowledgeSource,
  deleteTag,
  getAdminAppeals,
  getAdminFeedbacks,
  getAdminConfig,
  getAdminImages,
  getAdminOverview,
  getAdminReports,
  getAdminReviews,
  getAdminUsers,
  getCancellationRequests,
  getTags,
  getClubApplications,
  getKnowledgeSources,
  getCurrentAdmin,
  getPostPinRequests,
  getUserLevelRequests,
  handleAdminAppeal,
  handleAdminFeedback,
  handleAdminImage,
  handleAdminReport,
  handleAdminReview,
  handleAdminUser,
  handleCancellationRequest,
  handleClubApplication,
  handlePostPinRequest,
  handleUserLevelRequest,
  reindexKnowledge,
  renameTag,
  updateAdminConfig,
  updateKnowledgeSource
} from '../../api/admin';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';

const TABS = [
  { key: 'overview', label: '概览' },
  { key: 'reviews', label: '审核' },
  { key: 'reports', label: '举报' },
  { key: 'images', label: '图片' },
  { key: 'users', label: '用户' },
  { key: 'requests', label: '申请' },
  { key: 'feedback', label: '反馈' },
  { key: 'system', label: '系统' }
];

const REVIEW_TYPES = [
  { key: 'post', label: '帖子' },
  { key: 'comment', label: '评论' }
];

const REVIEW_STATUSES = [
  { key: 'pending', label: '待审' },
  { key: 'risk', label: '风险' },
  { key: 'approved', label: '通过' },
  { key: 'rejected', label: '驳回' },
  { key: 'all', label: '全部' }
];

const REPORT_STATUSES = [
  { key: 'pending', label: '待处理' },
  { key: 'resolved', label: '已处理' },
  { key: 'misreport', label: '误报' },
  { key: 'all', label: '全部' }
];

const REQUEST_TYPES = [
  { key: 'pin', label: '置顶' },
  { key: 'level', label: '等级' },
  { key: 'cancel', label: '注销' },
  { key: 'appeal', label: '申诉' },
  { key: 'club', label: '社团' }
];

const REQUEST_STATUSES = [
  { key: 'pending', label: '待处理' },
  { key: 'approved', label: '通过' },
  { key: 'rejected', label: '驳回' },
  { key: 'all', label: '全部' }
];

const SYSTEM_TYPES = [
  { key: 'config', label: '配置' },
  { key: 'tags', label: '标签' },
  { key: 'knowledge', label: '知识库' }
];

// Mini program admins sign in with their student account, which the backend
// treats as a secondary admin: only pin and club requests and the knowledge
// base are open to them. Everything else answers 403.
const FEEDBACK_STATUSES = [
  { key: 'pending', label: '待处理' },
  { key: 'resolved', label: '已回复' },
  { key: 'closed', label: '已关闭' },
  { key: 'all', label: '全部' }
];

const FEEDBACK_STATUS_TEXT = { pending: '待处理', resolved: '已回复', closed: '已关闭' };

const SECONDARY_TABS = ['requests', 'system'];
const SECONDARY_REQUEST_TYPES = ['pin', 'club'];
const SECONDARY_SYSTEM_TYPES = ['knowledge'];

const STATUS_TEXT = {
  pending: '待处理',
  approved: '已通过',
  rejected: '已驳回',
  resolved: '已处理',
  misreport: '误报',
  closed: '已关闭',
  risk: '风险',
  deleted: '已删除',
  all: '全部'
};

const reviewLabel = (value) => STATUS_TEXT[String(value || '').toLowerCase()] || value || '';

const buildRequestRows = (rows) => rows.map((item) => ({
  ...item,
  statusText: reviewLabel(item.status || item.reviewStatus),
  displayTitle: item.title || item.postTitle || item.name || item.appealType || item.reason || item.id,
  displayUser: item.userNickname || item.applicantName || item.authorNickname || item.email || item.userEmail || item.studentId || item.userId || '',
  displayContent: item.reason || item.reviewNote || item.description || item.content || item.summary || ''
}));

Page({
  data: {
    tabs: TABS,
    reviewTypes: REVIEW_TYPES,
    reviewStatuses: REVIEW_STATUSES,
    reportStatuses: REPORT_STATUSES,
    feedbackStatuses: FEEDBACK_STATUSES,
    feedbackStatus: 'pending',
    feedbacks: [],
    requestTypes: REQUEST_TYPES,
    requestStatuses: REQUEST_STATUSES,
    systemTypes: SYSTEM_TYPES,
    activeTab: 'overview',
    reviewType: 'post',
    reviewStatus: 'pending',
    reportStatus: 'pending',
    requestType: 'pin',
    requestStatus: 'pending',
    systemType: 'config',
    loading: true,
    errorMessage: '',
    admin: null,
    noPermission: false,
    overview: null,
    overviewCards: [],
    reviews: [],
    reports: [],
    images: [],
    users: [],
    requestRows: [],
    sensitiveWordsText: '',
    rateRulesText: '',
    tags: [],
    knowledgeForm: {
      name: '',
      sourceUrl: '',
      authority: 'curated',
      content: ''
    },
    knowledgeSources: [],
    knowledgeIndex: {},
    submitting: false
  },

  onLoad() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.bootstrap();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  onPullDownRefresh() {
    this.loadActiveTab().finally(() => wx.stopPullDownRefresh());
  },

  async bootstrap() {
    this.setData({
      loading: true,
      noPermission: false,
      errorMessage: ''
    });
    try {
      const admin = await getCurrentAdmin();
      if (admin.isPrimary) {
        this.setData({ admin });
      } else {
        const keep = (list, keys) => list.filter((item) => keys.includes(item.key));
        this.setData({
          admin,
          tabs: keep(TABS, SECONDARY_TABS),
          requestTypes: keep(REQUEST_TYPES, SECONDARY_REQUEST_TYPES),
          systemTypes: keep(SYSTEM_TYPES, SECONDARY_SYSTEM_TYPES),
          activeTab: SECONDARY_TABS.includes(this.data.activeTab) ? this.data.activeTab : 'requests',
          requestType: SECONDARY_REQUEST_TYPES.includes(this.data.requestType) ? this.data.requestType : 'pin',
          systemType: SECONDARY_SYSTEM_TYPES.includes(this.data.systemType) ? this.data.systemType : 'knowledge'
        });
      }
      await this.loadActiveTab();
    } catch (error) {
      // Signed in but not an admin: the backend answers 401 for a plain
      // user token and 403 for a missing role.
      const forbidden = [401, 403].includes(Number(error && error.statusCode));
      this.setData({
        loading: false,
        noPermission: forbidden,
        errorMessage: forbidden ? '' : '管理员身份校验失败，请重试'
      });
    }
  },

  async loadActiveTab() {
    // Retrying after the admin check itself failed runs the check again.
    if (!this.data.admin) return this.bootstrap();
    const { activeTab } = this.data;
    if (activeTab === 'overview') return this.loadOverview();
    if (activeTab === 'reviews') return this.loadReviews();
    if (activeTab === 'reports') return this.loadReports();
    if (activeTab === 'images') return this.loadImages();
    if (activeTab === 'users') return this.loadUsers();
    if (activeTab === 'requests') return this.loadRequests();
    if (activeTab === 'feedback') return this.loadFeedbacks();
    if (activeTab === 'system') return this.loadSystem();
    return Promise.resolve();
  },

  switchTab(event) {
    const key = event.currentTarget.dataset.key;
    if (!key || key === this.data.activeTab) return;
    this.setData({ activeTab: key }, () => this.loadActiveTab());
  },

  setReviewType(event) {
    this.setData({ reviewType: event.currentTarget.dataset.key }, () => this.loadReviews());
  },

  setReviewStatus(event) {
    this.setData({ reviewStatus: event.currentTarget.dataset.key }, () => this.loadReviews());
  },

  setReportStatus(event) {
    this.setData({ reportStatus: event.currentTarget.dataset.key }, () => this.loadReports());
  },

  setFeedbackStatus(event) {
    this.setData({ feedbackStatus: event.currentTarget.dataset.key }, () => this.loadFeedbacks());
  },

  setRequestType(event) {
    this.setData({ requestType: event.currentTarget.dataset.key }, () => this.loadRequests());
  },

  setRequestStatus(event) {
    this.setData({ requestStatus: event.currentTarget.dataset.key }, () => this.loadRequests());
  },

  setSystemType(event) {
    this.setData({ systemType: event.currentTarget.dataset.key }, () => this.loadSystem());
  },

  async loadOverview() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const overview = await getAdminOverview();
      const overviewCards = [
        { label: '用户', value: overview.totalUsers || 0 },
        { label: '帖子', value: overview.totalPosts || 0 },
        { label: '评论', value: overview.totalComments || 0 },
        { label: '待审', value: overview.pendingReviewCount || overview.pendingReviews || 0 },
        { label: '举报', value: overview.pendingReportCount || overview.pendingReports || 0 },
        { label: '图片', value: overview.pendingImageCount || overview.pendingImages || 0 },
        { label: '反馈', value: overview.pendingFeedbacks }
      ];
      this.setData({ overview, overviewCards, loading: false, errorMessage: '' });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '概览加载失败，请重试' });
    }
  },

  async loadReviews() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const rows = await getAdminReviews({
        type: this.data.reviewType,
        status: this.data.reviewStatus
      });
      this.setData({
        reviews: rows.map((item) => ({
          ...item,
          statusText: reviewLabel(item.reviewStatus)
        })),
        loading: false,
        errorMessage: ''
      });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '审核列表加载失败，请重试' });
    }
  },

  async loadReports() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const reports = await getAdminReports({ status: this.data.reportStatus });
      this.setData({
        reports: reports.map((item) => ({
          ...item,
          statusText: reviewLabel(item.status),
          displayTitle: item.targetTitle || item.title || item.targetId || item.id
        })),
        loading: false,
        errorMessage: ''
      });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '举报列表加载失败，请重试' });
    }
  },

  async loadImages() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const images = await getAdminImages();
      this.setData({
        images: images.map((item) => ({
          ...item,
          statusText: reviewLabel(item.status)
        })),
        loading: false,
        errorMessage: ''
      });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '图片列表加载失败，请重试' });
    }
  },

  async loadUsers() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const users = await getAdminUsers();
      this.setData({
        users: users.map((item) => ({
          ...item,
          statusText: item.deleted ? '已注销' : item.banned ? '已封禁' : item.muted ? '已禁言' : '正常',
          displayName: item.alias || item.nickname || item.email || item.studentId || item.id
        })),
        loading: false,
        errorMessage: ''
      });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '用户列表加载失败，请重试' });
    }
  },

  async loadFeedbacks() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const rows = await getAdminFeedbacks({ status: this.data.feedbackStatus });
      this.setData({
        feedbacks: rows.map((item) => ({
          ...item,
          statusText: FEEDBACK_STATUS_TEXT[item.status] || item.status,
          displayUser: [item.userNickname, item.studentId ? `学号 ${item.studentId}` : item.userEmail]
            .filter(Boolean).join(' · ')
        })),
        loading: false,
        errorMessage: ''
      });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '反馈列表加载失败，请重试' });
    }
  },

  async loadRequests() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const status = this.data.requestStatus;
      let rows = [];
      if (this.data.requestType === 'pin') rows = await getPostPinRequests({ status });
      if (this.data.requestType === 'level') rows = await getUserLevelRequests({ status });
      if (this.data.requestType === 'cancel') rows = await getCancellationRequests({ status });
      if (this.data.requestType === 'appeal') rows = await getAdminAppeals({ status });
      if (this.data.requestType === 'club') rows = await getClubApplications({ status: status === 'all' ? '' : status });
      this.setData({
        requestRows: buildRequestRows(rows),
        loading: false,
        errorMessage: ''
      });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '申请列表加载失败，请重试' });
    }
  },

  async loadSystem() {
    if (this.data.systemType === 'config') return this.loadConfig();
    if (this.data.systemType === 'tags') return this.loadTags();
    if (this.data.systemType === 'knowledge') return this.loadKnowledgeSources();
    this.setData({ loading: false });
    return Promise.resolve();
  },

  async loadConfig() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const config = await getAdminConfig();
      this.setData({
        sensitiveWordsText: (config.sensitiveWords || []).join('\n'),
        rateRulesText: JSON.stringify(config.settings, null, 2),
        loading: false,
        errorMessage: ''
      });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '系统配置加载失败，请重试' });
    }
  },

  async loadTags() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const tags = await getTags();
      this.setData({ tags, loading: false, errorMessage: '' });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '标签加载失败，请重试' });
    }
  },

  async loadKnowledgeSources() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const data = await getKnowledgeSources();
      this.setData({
        knowledgeSources: data.items || [],
        knowledgeIndex: data.index || {},
        loading: false,
        errorMessage: ''
      });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '知识库加载失败，请重试' });
    }
  },

  async runAction(action) {
    if (this.data.submitting) return;
    this.setData({ submitting: true });
    wx.showLoading({ title: '处理中' });
    try {
      await action();
      wx.hideLoading();
      wx.showToast({ title: '已完成', icon: 'success' });
      await this.loadActiveTab();
    } catch (error) {
      wx.hideLoading();
    }
    this.setData({ submitting: false });
  },

  askNote({ title, placeholderText = '处理备注', confirmText = '确定' }, onConfirm) {
    wx.showModal({
      title,
      editable: true,
      placeholderText,
      confirmText,
      success: (res) => {
        if (!res.confirm) return;
        onConfirm(String(res.content || '').trim());
      }
    });
  },

  confirm({ title, content = '', confirmText = '确定' }, onConfirm) {
    wx.showModal({
      title,
      content,
      confirmText,
      success: (res) => {
        if (res.confirm) onConfirm();
      }
    });
  },

  actReview(event) {
    const { id, action } = event.currentTarget.dataset;
    this.runAction(() => handleAdminReview({ type: this.data.reviewType, id, action }));
  },

  actReport(event) {
    const { id, action } = event.currentTarget.dataset;
    this.askNote({ title: '处理举报', placeholderText: '处理结果', confirmText: '提交' }, (reviewNote) => {
      this.runAction(() => handleAdminReport(id, { action, reviewNote }));
    });
  },

  actImage(event) {
    const { id, action } = event.currentTarget.dataset;
    this.askNote({ title: '审核图片', placeholderText: '审核备注', confirmText: '提交' }, (reviewNote) => {
      this.runAction(() => handleAdminImage(id, { action, reviewNote }));
    });
  },

  actUser(event) {
    const { id, action } = event.currentTarget.dataset;
    const titleMap = {
      mute: '禁言用户',
      unmute: '解除禁言',
      ban: '封禁用户',
      unban: '解除封禁',
      cancel: '注销账号',
      restore: '恢复账号',
      grant_admin: '设为管理员',
      revoke_admin: '移除管理员'
    };
    const needsNote = ['mute', 'ban', 'cancel', 'grant_admin', 'revoke_admin'].includes(action);
    if (needsNote) {
      this.askNote({ title: titleMap[action], placeholderText: '处理备注', confirmText: '提交' }, (reviewNote) => {
        this.runAction(() => handleAdminUser(id, { action, reviewNote }));
      });
      return;
    }
    this.confirm({ title: titleMap[action], confirmText: '确定' }, () => {
      this.runAction(() => handleAdminUser(id, { action }));
    });
  },

  // 回复 needs text (the user sees it); 关闭 may go without.
  actFeedback(event) {
    const { id, action } = event.currentTarget.dataset;
    const reply = action === 'reply';
    this.askNote({
      title: reply ? '回复反馈' : '关闭反馈',
      placeholderText: reply ? '回复内容（用户可见）' : '说明（选填，用户可见）',
      confirmText: reply ? '发送' : '关闭'
    }, (text) => {
      if (reply && !text) {
        wx.showToast({ title: '回复内容不能为空', icon: 'none' });
        return;
      }
      this.runAction(() => handleAdminFeedback(id, { action, reply: text }));
    });
  },

  actRequest(event) {
    const { id, action } = event.currentTarget.dataset;
    this.askNote({ title: '处理申请', placeholderText: '处理备注', confirmText: '提交' }, (reviewNote) => {
      const payload = { action, reviewNote };
      this.runAction(() => {
        if (this.data.requestType === 'pin') return handlePostPinRequest(id, payload);
        if (this.data.requestType === 'level') return handleUserLevelRequest(id, payload);
        // The cancellation handler reads `note`; the others take reviewNote.
        if (this.data.requestType === 'cancel') return handleCancellationRequest(id, { action, note: reviewNote });
        if (this.data.requestType === 'appeal') return handleAdminAppeal(id, payload);
        return handleClubApplication(id, payload);
      });
    });
  },

  onSensitiveInput(event) {
    this.setData({ sensitiveWordsText: event.detail.value });
  },

  onRateRulesInput(event) {
    this.setData({ rateRulesText: event.detail.value });
  },

  saveConfig() {
    let settings = {};
    try {
      settings = JSON.parse(this.data.rateRulesText || '{}');
    } catch (error) {
      wx.showToast({ title: '频控配置不是有效 JSON', icon: 'none' });
      return;
    }
    const sensitiveWords = this.data.sensitiveWordsText
      .split(/\r?\n/)
      .map((item) => item.trim())
      .filter(Boolean);
    this.runAction(() => updateAdminConfig({ sensitiveWords, settings }));
  },

  addTag() {
    this.askNote({ title: '新增标签', placeholderText: '标签名称', confirmText: '保存' }, (value) => {
      if (!value) return;
      this.runAction(() => addTag(value));
    });
  },

  editTag(event) {
    const name = event.currentTarget.dataset.name;
    this.askNote({ title: '重命名标签', placeholderText: name, confirmText: '保存' }, (value) => {
      if (!value) return;
      this.runAction(() => renameTag(name, value));
    });
  },

  removeTag(event) {
    const name = event.currentTarget.dataset.name;
    this.confirm({ title: '删除标签', content: name, confirmText: '删除' }, () => {
      this.runAction(() => deleteTag(name));
    });
  },

  onKnowledgeInput(event) {
    const key = event.currentTarget.dataset.key;
    this.setData({ [`knowledgeForm.${key}`]: event.detail.value });
  },

  saveKnowledgeSource() {
    const payload = {
      name: this.data.knowledgeForm.name.trim(),
      sourceUrl: this.data.knowledgeForm.sourceUrl.trim(),
      authority: this.data.knowledgeForm.authority || 'curated',
      content: this.data.knowledgeForm.content.trim()
    };
    if (!payload.name) {
      wx.showToast({ title: '名称不能为空', icon: 'none' });
      return;
    }
    this.runAction(async () => {
      await createKnowledgeSource(payload);
      this.setData({ knowledgeForm: { name: '', sourceUrl: '', authority: 'curated', content: '' } });
    });
  },

  editKnowledgeSource(event) {
    const id = event.currentTarget.dataset.id;
    const source = this.data.knowledgeSources.find((item) => item.id === id);
    if (!source) return;
    this.askNote({ title: '修改知识来源名称', placeholderText: source.name, confirmText: '保存' }, (name) => {
      if (!name) return;
      this.runAction(() => updateKnowledgeSource(id, { name }));
    });
  },

  removeKnowledgeSource(event) {
    const id = event.currentTarget.dataset.id;
    const source = this.data.knowledgeSources.find((item) => item.id === id);
    this.confirm({ title: '删除知识来源', content: source ? source.name : id, confirmText: '删除' }, () => {
      this.runAction(() => deleteKnowledgeSource(id));
    });
  },

  reindexKnowledge() {
    this.confirm({ title: '重建知识库索引', confirmText: '重建' }, () => {
      this.runAction(() => reindexKnowledge());
    });
  }
});
