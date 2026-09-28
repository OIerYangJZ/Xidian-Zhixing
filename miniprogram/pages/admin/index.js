import {
  actAdminAccount,
  addTag,
  createAdminAccount,
  createKnowledgeSource,
  createSection,
  exportAdminData,
  getAdminAccounts,
  getAdminAnnouncements,
  getAiTrace,
  getSections,
  publishAnnouncement,
  rebuildHotTopics,
  updateSection,
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
  { key: 'announcements', label: '公告' },
  { key: 'sections', label: '分区' },
  { key: 'hot', label: '热榜' },
  { key: 'export', label: '导出' },
  { key: 'accounts', label: '管理员' },
  { key: 'knowledge', label: '知识库' }
];

const SECTION_TYPES = [
  { key: 'general', label: '综合' },
  { key: 'college', label: '学院' },
  { key: 'club', label: '社团' }
];

// GET /api/admin/export scopes (build_export_payload).
const EXPORT_SCOPES = [
  { key: 'users', label: '用户' },
  { key: 'posts', label: '帖子' },
  { key: 'comments', label: '评论' },
  { key: 'reports', label: '举报' },
  { key: 'appeals', label: '申诉' },
  { key: 'cancellations', label: '注销' },
  { key: 'userlevelrequests', label: '等级申请' },
  { key: 'postpinrequests', label: '置顶申请' },
  { key: 'auditlogs', label: '操作日志' }
];

const EMPTY_ANNOUNCEMENT = { title: '', content: '', type: '系统公告', isImportant: false };
const EMPTY_SECTION = { sectionType: 'college', sectionId: '', name: '', description: '', ruleText: '', sortOrder: '' };
const EMPTY_ACCOUNT = { username: '', password: '' };
// A trace is JSON; past this it is cut, a page cannot show megabytes.
const TRACE_TEXT_LIMIT = 20000;

// Mini program admins sign in with their student account, which the backend
// treats as a secondary admin: only pin and club requests, sections, the hot
// list rebuild and the knowledge base (with AI traces) are open to them.
// Everything else answers 403.
const FEEDBACK_STATUSES = [
  { key: 'pending', label: '待处理' },
  { key: 'resolved', label: '已回复' },
  { key: 'closed', label: '已关闭' },
  { key: 'all', label: '全部' }
];

const FEEDBACK_STATUS_TEXT = { pending: '待处理', resolved: '已回复', closed: '已关闭' };

const SECONDARY_TABS = ['requests', 'system'];
const SECONDARY_REQUEST_TYPES = ['pin', 'club'];
const SECONDARY_SYSTEM_TYPES = ['sections', 'hot', 'knowledge'];

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
    traceId: '',
    traceText: '',
    announcements: [],
    announcementForm: { ...EMPTY_ANNOUNCEMENT },
    sections: [],
    sectionTypes: SECTION_TYPES,
    sectionForm: { ...EMPTY_SECTION },
    hotRows: [],
    hotRebuiltAt: '',
    exportScopes: EXPORT_SCOPES,
    exportScope: 'users',
    exportFile: null,
    adminAccounts: [],
    accountForm: { ...EMPTY_ACCOUNT },
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
    if (this.data.systemType === 'announcements') return this.loadAnnouncements();
    if (this.data.systemType === 'sections') return this.loadSections();
    if (this.data.systemType === 'accounts') return this.loadAdminAccounts();
    // 热榜 and 导出 load nothing until asked.
    this.setData({ loading: false, errorMessage: '' });
    return Promise.resolve();
  },

  async loadAnnouncements() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const announcements = await getAdminAnnouncements();
      this.setData({ announcements, loading: false, errorMessage: '' });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '公告加载失败，请重试' });
    }
  },

  async loadSections() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const typeLabel = SECTION_TYPES.reduce((map, item) => ({ ...map, [item.key]: item.label }), {});
      const sections = (await getSections()).map((item) => ({ ...item, typeLabel: typeLabel[item.sectionType] || item.sectionType }));
      this.setData({ sections, loading: false, errorMessage: '' });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '分区加载失败，请重试' });
    }
  },

  async loadAdminAccounts() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const adminAccounts = await getAdminAccounts();
      this.setData({ adminAccounts, loading: false, errorMessage: '' });
    } catch (error) {
      this.setData({ loading: false, errorMessage: '管理员账号加载失败，请重试' });
    }
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
  },

  // ---- AI 追踪: the traceId comes with each AI chat answer. ----

  onTraceIdInput(event) {
    this.setData({ traceId: event.detail.value });
  },

  async lookupTrace() {
    const traceId = this.data.traceId.trim();
    if (!traceId) {
      wx.showToast({ title: '请输入 traceId', icon: 'none' });
      return;
    }
    wx.showLoading({ title: '查询中' });
    try {
      const trace = await getAiTrace(traceId);
      const text = JSON.stringify(trace, null, 2);
      this.setData({
        traceText: text.length > TRACE_TEXT_LIMIT ? `${text.slice(0, TRACE_TEXT_LIMIT)}\n…（已截断）` : text
      });
    } catch (error) {
      this.setData({ traceText: '' });
    } finally {
      wx.hideLoading();
    }
  },

  copyTrace() {
    if (this.data.traceText) wx.setClipboardData({ data: this.data.traceText });
  },

  // ---- 公告 ----

  onAnnouncementInput(event) {
    const key = event.currentTarget.dataset.key;
    this.setData({ [`announcementForm.${key}`]: event.detail.value });
  },

  toggleAnnouncementImportant() {
    this.setData({ 'announcementForm.isImportant': !this.data.announcementForm.isImportant });
  },

  publishAnnouncement() {
    const form = this.data.announcementForm;
    const payload = {
      title: form.title.trim(),
      content: form.content.trim(),
      type: form.type.trim() || '系统公告',
      isImportant: Boolean(form.isImportant)
    };
    if (!payload.title || !payload.content) {
      wx.showToast({ title: '标题和内容不能为空', icon: 'none' });
      return;
    }
    this.confirm({ title: '发布公告', content: payload.title, confirmText: '发布' }, () => {
      this.runAction(async () => {
        await publishAnnouncement(payload);
        this.setData({ announcementForm: { ...EMPTY_ANNOUNCEMENT } });
      });
    });
  },

  // ---- 分区: sectionId is the section's identity and never changes. ----

  onSectionFormInput(event) {
    const key = event.currentTarget.dataset.key;
    this.setData({ [`sectionForm.${key}`]: event.detail.value });
  },

  setSectionFormType(event) {
    this.setData({ 'sectionForm.sectionType': event.currentTarget.dataset.key });
  },

  createSection() {
    const form = this.data.sectionForm;
    const payload = {
      sectionType: form.sectionType,
      sectionId: form.sectionId.trim(),
      name: form.name.trim(),
      description: form.description.trim(),
      ruleText: form.ruleText.trim()
    };
    if (String(form.sortOrder).trim()) payload.sortOrder = Number(form.sortOrder);
    if (!payload.name) {
      wx.showToast({ title: '名称不能为空', icon: 'none' });
      return;
    }
    if (!/^[0-9A-Za-z_-]{1,80}$/.test(payload.sectionId)) {
      wx.showToast({ title: 'sectionId 只能用字母、数字、- 和 _', icon: 'none' });
      return;
    }
    this.runAction(async () => {
      await createSection(payload);
      this.setData({ sectionForm: { ...EMPTY_SECTION } });
    });
  },

  editSection(event) {
    const { id, field } = event.currentTarget.dataset;
    const section = this.data.sections.find((item) => item.sectionId === id);
    if (!section) return;
    const titles = { name: '修改名称', description: '修改说明', ruleText: '修改发帖规则', sortOrder: '修改排序（数字越小越靠前）' };
    const current = field === 'name' ? (section.sectionName || section.name) : section[field];
    this.askNote({ title: titles[field], placeholderText: String(current === undefined ? '' : current) || '（空）', confirmText: '保存' }, (value) => {
      // An empty answer is a cancel: the prompt starts empty, not prefilled.
      if (!value) return;
      let payload;
      if (field === 'name') payload = { name: value, sectionName: value };
      else if (field === 'sortOrder') {
        if (!/^-?\d+$/.test(value)) {
          wx.showToast({ title: '排序需要整数', icon: 'none' });
          return;
        }
        payload = { sortOrder: Number(value) };
      } else payload = { [field]: value };
      this.runAction(() => updateSection(id, payload));
    });
  },

  disableSection(event) {
    const id = event.currentTarget.dataset.id;
    const section = this.data.sections.find((item) => item.sectionId === id);
    this.confirm({
      title: '停用分区',
      content: `${section ? section.sectionName : id}：停用后不再出现在分区列表，这里也无法再次启用，需到管理后台处理。`,
      confirmText: '停用'
    }, () => {
      this.runAction(() => updateSection(id, { enabled: false }));
    });
  },

  // ---- 热榜 ----

  rebuildHotTopics() {
    this.confirm({ title: '重新生成今日热榜', confirmText: '生成' }, () => {
      this.runAction(async () => {
        const rows = await rebuildHotTopics();
        const now = new Date();
        this.setData({
          hotRows: rows.slice(0, 20),
          hotRebuiltAt: `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`
        });
      });
    });
  },

  // ---- 导出: the backend sends the file's text; it is written to a local
  // file that can be sent to a WeChat chat (the only way to get it out). ----

  setExportScope(event) {
    this.setData({ exportScope: event.currentTarget.dataset.key, exportFile: null });
  },

  async generateExport() {
    if (this.data.submitting) return;
    this.setData({ submitting: true });
    wx.showLoading({ title: '生成中' });
    try {
      const result = await exportAdminData({ scope: this.data.exportScope, format: 'csv' });
      const filePath = `${wx.env.USER_DATA_PATH}/${result.fileName}`;
      // A BOM so spreadsheet apps read the Chinese text as UTF-8.
      wx.getFileSystemManager().writeFileSync(filePath, `\ufeff${result.data}`, 'utf8');
      this.setData({
        exportFile: { filePath, fileName: result.fileName, rowCount: result.rowCount, text: result.data }
      });
      wx.hideLoading();
    } catch (error) {
      wx.hideLoading();
      wx.showToast({ title: (error && error.data && error.data.message) || '导出失败', icon: 'none' });
    }
    this.setData({ submitting: false });
  },

  // Must run from the tap itself: WeChat refuses shareFileMessage otherwise.
  shareExportFile() {
    const file = this.data.exportFile;
    if (!file) return;
    wx.shareFileMessage({
      filePath: file.filePath,
      fileName: file.fileName,
      fail: (error) => {
        if (!/cancel/i.test(String(error && error.errMsg))) wx.showToast({ title: '发送失败，可改用复制内容', icon: 'none' });
      }
    });
  },

  copyExportFile() {
    if (this.data.exportFile) wx.setClipboardData({ data: this.data.exportFile.text });
  },

  // ---- 管理员账号 (primary admins only; new accounts are secondary). ----

  onAccountInput(event) {
    const key = event.currentTarget.dataset.key;
    this.setData({ [`accountForm.${key}`]: event.detail.value });
  },

  createAdminAccount() {
    const username = this.data.accountForm.username.trim();
    const password = this.data.accountForm.password;
    if (!/^[A-Za-z0-9_.-]{3,32}$/.test(username)) {
      wx.showToast({ title: '用户名需 3-32 位字母、数字或 _ . -', icon: 'none' });
      return;
    }
    if (!password) {
      wx.showToast({ title: '请填写初始密码', icon: 'none' });
      return;
    }
    this.runAction(async () => {
      await createAdminAccount(username, password);
      this.setData({ accountForm: { ...EMPTY_ACCOUNT } });
    });
  },

  actAdminAccount(event) {
    const { id, action } = event.currentTarget.dataset;
    const account = this.data.adminAccounts.find((item) => item.id === id);
    const deactivate = action === 'deactivate';
    this.confirm({
      title: deactivate ? '注销管理员账号' : '重新启用管理员账号',
      content: `${account ? account.username : id}${deactivate ? '：会立即退出所有登录' : ''}`,
      confirmText: deactivate ? '注销' : '启用'
    }, () => {
      this.runAction(() => actAdminAccount(id, action));
    });
  }
});
