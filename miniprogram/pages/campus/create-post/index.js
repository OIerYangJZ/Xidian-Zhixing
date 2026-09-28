import { getUserInfo } from '../../../api/auth';
import { getSectionsTree } from '../../../api/campus';
import { getClubs } from '../../../api/clubs';
import { createPost, getRandomAnonymousAlias } from '../../../api/posts';
import { uploadPostImage } from '../../../api/uploads';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { sectionTone } from '../../../utils/format';
import { markdownToNodes } from '../../../utils/markdown';

const MAX_IMAGE_COUNT = 9;
// The server's limits (_post_handler.py _MAX_POST_*, _MAX_TAGS).
const CONTENT_LIMIT = 10000;
const TITLE_LIMIT = 200;
const TAG_LIMIT = 10;
const DRAFT_KEY = 'createPostDraft';
const STATUS_OPTIONS = [
  { label: '进行中', value: 'ongoing', icon: 'help' },
  { label: '已解决', value: 'resolved', icon: 'check' },
  { label: '已结束', value: 'closed', icon: 'lock' }
];
const PIN_OPTIONS = [
  { label: '不置顶', minutes: null },
  { label: '30 分钟', minutes: 30 },
  { label: '1 小时', minutes: 60 },
  { label: '2 小时', minutes: 120 },
  { label: '3 小时', minutes: 180 },
  { label: '1 天', minutes: 1440 },
  { label: '3 天', minutes: 4320 }
];
const TAG_OPTIONS = [
  '找对象',
  '找搭子',
  '交友扩列',
  '吐槽日常',
  '八卦吃瓜',
  '求助问答',
  '失物招领',
  '二手交易',
  '学习交流',
  '活动拼车',
  '求助',
  '学习',
  '二手',
  '组队',
  '经验',
  '吐槽',
  '交友',
  '活动',
  '租房',
  '实习',
  '考研',
  '保研',
  '出国',
  '竞赛',
  '社团'
];
const VISIBILITY_OPTIONS = [
  { label: '所有人可见', value: 'public', icon: 'public' },
  { label: '仅自己可见', value: 'private', icon: 'lock' }
];

// The server's own extraction (_extract_inline_tags), so the chips are the
// tags the post will get.
function extractInlineTags(...values) {
  const tags = [];
  values.forEach((value) => {
    // Python's \w is Unicode-aware; JS needs \p{L}\p{N} and the u flag.
    String(value || '').replace(/#([\p{L}\p{N}_-]{1,30})/gu, (_, tag) => {
      const cleanTag = String(tag || '').trim();
      if (cleanTag && !tags.includes(cleanTag)) tags.push(cleanTag);
      return '';
    });
  });
  return tags;
}

function buildInlineSegments(value) {
  const text = String(value || '');
  const segments = [];
  const pattern = /#([^\s#]{1,30})(?=\s)/g;
  let cursor = 0;
  let match = pattern.exec(text);
  while (match) {
    if (match.index > cursor) {
      segments.push({ type: 'text', text: text.slice(cursor, match.index) });
    }
    segments.push({ type: 'tag', text: match[0] });
    cursor = match.index + match[0].length;
    match = pattern.exec(text);
  }
  if (cursor < text.length) {
    segments.push({ type: 'text', text: text.slice(cursor) });
  }
  return segments;
}


Page({
  data: {
    navTop: 0,
    navHeight: 0,
    loading: true,
    sections: [],
    sectionIndex: -1,
    sectionSelectorOpen: false,
    clubs: [],
    clubIdentityIndex: -1,
    clubIdentityOpen: false,

    title: '',
    titleLength: 0,
    content: '',
    // Handoff P1: Markdown with 编辑 / 预览, drafts, one-shot validation (P2).
    markdown: false,
    previewMode: false,
    previewNodes: [],
    tagChips: [],
    draftSavedAt: '',
    showErrors: false,
    titleError: '',
    sectionError: '',
    contentError: '',
    errorCount: 0,
    clubIdentityLabel: '以个人身份',
    contentLength: 0,
    contentCursor: 0,
    contentSegments: [],
    canPublish: false,

    tagSelectorOpen: false,
    customTagText: '',
    tagOptions: TAG_OPTIONS,

    statusOptions: STATUS_OPTIONS,
    postStatusIndex: 0,
    selectedStatus: STATUS_OPTIONS[0],
    statusSelectorOpen: false,

    pinOptions: PIN_OPTIONS,
    pinIndex: 0,
    pinSelectorOpen: false,
    isLevelOneUser: false,
    userCollege: '',
    userMajor: '',

    useAnonymousAlias: false,
    anonymousAlias: '',

    visibilityOptions: VISIBILITY_OPTIONS,
    privateOnly: false,
    visibilitySelectorOpen: false,

    images: [],
    loadErrorMessage: '',
    isUploading: false,
    isPublishing: false
  },

  onLoad() {
    this.initCustomNav();
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadInitialData();
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
  },

  initCustomNav() {
    const app = getApp();
    this.setData({
      navTop: app.globalData.navTop || 44,
      navHeight: app.globalData.navHeight || 32
    });
  },

  async loadSections() {
    const response = await getSectionsTree();
    const tree = response.data || response || {};
    const sections = [
      ...(tree.sections || []),
      ...(tree.colleges || []),
      ...(tree.clubs || [])
    ].filter(Boolean);
    const dedupedSections = [];
    sections.forEach((section) => {
      if (!dedupedSections.some((item) => item.sectionId === section.sectionId)) {
        dedupedSections.push(section);
      }
    });
    this.setData({
      sections: dedupedSections.map((section) => ({ ...section, tone: sectionTone(section.sectionName) })),
      sectionIndex: -1,
      loading: false
    });
  },

  async loadInitialData() {
    this.setData({ loadErrorMessage: '' });
    try {
      await Promise.all([
        this.loadSections(),
        this.loadClubs(),
        this.loadUserLevel()
      ]);
      // After both lists: a draft's section and identity name one of each.
      this.restoreDraft();
    } catch (error) {
      this.setData({
        loading: false,
        loadErrorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '发布配置加载失败，请重试'
      });
    }
  },

  retryLoadInitialData() {
    this.loadInitialData();
  },

  async loadClubs() {
    // Only clubs the server lets this user post as (owner / manager).
    const clubs = (await getClubs()).filter((club) => club.canPublishAs);
    this.setData({ clubs });
  },

  async loadUserLevel() {
    try {
      const response = await getUserInfo();
      const profile = response.data || {};
      this.setData({
        isLevelOneUser: Boolean(profile.isLevelOneUser),
        userCollege: profile.college || '',
        userMajor: profile.major || ''
      });
    } catch (error) {}
  },

  updatePublishState(nextContent) {
    const content = nextContent == null ? this.data.content : nextContent;
    this.setData({
      contentLength: content.length,
      contentSegments: buildInlineSegments(content),
      canPublish: content.trim().length > 0 && !this.data.isPublishing
    });
  },

  closeInlineSelectors() {
    this.setData({
      sectionSelectorOpen: false,
      clubIdentityOpen: false,
      tagSelectorOpen: false,
      statusSelectorOpen: false,
      pinSelectorOpen: false,
      visibilitySelectorOpen: false
    });
  },

  onTitleInput(event) {
    const title = event.detail.value.slice(0, TITLE_LIMIT);
    this.setData({ title, titleLength: title.length });
    this.afterEdit();
  },

  // ---- validation (handoff P2) ----

  validate() {
    const title = this.data.title.trim();
    const titleError = !title ? '请填写标题' : (title.length > TITLE_LIMIT ? `标题最多 ${TITLE_LIMIT} 字` : '');
    const sectionError = this.data.sectionIndex < 0 ? '请选择分区' : '';
    const contentError = this.data.content.trim() ? '' : '请填写正文';
    const errorCount = [titleError, sectionError, contentError].filter(Boolean).length;
    return { titleError, sectionError, contentError, errorCount };
  },

  refreshErrors() {
    if (this.data.showErrors) this.setData(this.validate());
  },

  // ---- drafts ----

  afterEdit() {
    this.setData({ tagChips: extractInlineTags(this.data.title, this.data.content) });
    this.refreshErrors();
    clearTimeout(this._draftTimer);
    this._draftTimer = setTimeout(() => this.saveDraft(), 800);
  },

  saveDraft() {
    const { title, content, markdown, sectionIndex, sections, clubs, clubIdentityIndex, postStatusIndex, privateOnly, useAnonymousAlias, anonymousAlias } = this.data;
    if (!title.trim() && !content.trim()) {
      wx.removeStorageSync(DRAFT_KEY);
      this.setData({ draftSavedAt: '' });
      return;
    }
    const section = sectionIndex >= 0 ? sections[sectionIndex] : null;
    wx.setStorageSync(DRAFT_KEY, {
      title, content, markdown, postStatusIndex, privateOnly, useAnonymousAlias, anonymousAlias,
      sectionName: section ? section.sectionName : '',
      clubId: clubIdentityIndex >= 0 && clubs[clubIdentityIndex] ? clubs[clubIdentityIndex].id : ''
    });
    const now = new Date();
    this.setData({ draftSavedAt: `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}` });
  },

  restoreDraft() {
    const draft = wx.getStorageSync(DRAFT_KEY);
    if (!draft || (!draft.title && !draft.content)) return;
    const clubIdentityIndex = draft.clubId
      ? this.data.clubs.findIndex((club) => club.id === draft.clubId)
      : -1;
    const club = clubIdentityIndex >= 0 ? this.data.clubs[clubIdentityIndex] : null;
    let sectionIndex = this.data.sections.findIndex((item) => item.sectionName === draft.sectionName);
    // The club may no longer be one this user can post as.
    if (sectionIndex >= 0 && !this.clubFitsSection(club, this.data.sections[sectionIndex])) sectionIndex = -1;
    const statusIndex = Number.isInteger(draft.postStatusIndex) && draft.postStatusIndex >= 0 ? draft.postStatusIndex : 0;
    this.setData({
      title: draft.title || '',
      titleLength: (draft.title || '').length,
      content: draft.content || '',
      contentLength: (draft.content || '').length,
      contentSegments: buildInlineSegments(draft.content || ''),
      markdown: Boolean(draft.markdown),
      sectionIndex,
      clubIdentityIndex,
      clubIdentityLabel: club ? (club.name || club.clubName || '社团') : '以个人身份',
      postStatusIndex: statusIndex,
      selectedStatus: STATUS_OPTIONS[statusIndex],
      privateOnly: Boolean(draft.privateOnly),
      useAnonymousAlias: Boolean(draft.useAnonymousAlias),
      anonymousAlias: draft.anonymousAlias || '',
      tagChips: extractInlineTags(draft.title || '', draft.content || ''),
      draftSavedAt: '已恢复'
    });
    this.updatePublishState();
  },

  clearDraft() {
    wx.showModal({
      title: '清空草稿？',
      content: '标题、正文和已选设置会一并清空。',
      confirmText: '清空',
      confirmColor: '#B3261E',
      success: (res) => {
        if (!res.confirm) return;
        wx.removeStorageSync(DRAFT_KEY);
        this.setData({
          title: '', titleLength: 0, content: '', contentLength: 0, contentSegments: [], tagChips: [],
          images: [], sectionIndex: -1, markdown: false, previewMode: false, draftSavedAt: '',
          showErrors: false, titleError: '', sectionError: '', contentError: '', errorCount: 0
        });
        this.updatePublishState('');
      }
    });
  },

  // ---- Markdown ----

  toggleMarkdown() {
    this.setData({ markdown: !this.data.markdown, previewMode: false });
    this.afterEdit();
  },

  setEditMode(event) {
    const preview = event.currentTarget.dataset.mode === 'preview';
    this.setData({
      previewMode: preview,
      previewNodes: preview ? markdownToNodes(this.data.content) : []
    });
  },

  insertMarkdown(event) {
    const snippets = {
      bold: ['**', '粗体', '**'],
      italic: ['*', '斜体', '*'],
      list: ['\n- ', '', ''],
      quote: ['\n> ', '', ''],
      link: ['[', '链接文字', '](https://)']
    };
    const [before, middle, after] = snippets[event.currentTarget.dataset.kind] || ['', '', ''];
    const content = this.data.content;
    const cursor = Math.max(0, Math.min(this.data.contentCursor, content.length));
    const insert = `${before}${middle}${after}`;
    const next = `${content.slice(0, cursor)}${insert}${content.slice(cursor)}`.slice(0, CONTENT_LIMIT);
    this.setData({
      content: next,
      contentLength: next.length,
      contentCursor: cursor + insert.length,
      contentSegments: buildInlineSegments(next)
    });
    this.updatePublishState(next);
    this.afterEdit();
  },

  removeTag(event) {
    const tag = String(event.currentTarget.dataset.tag || '');
    if (!tag) return;
    const escaped = tag.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const next = this.data.content.replace(new RegExp(`\\s?#${escaped}(?=\\s|$)`, 'g'), '').trim();
    this.setData({ content: next, contentLength: next.length, contentSegments: buildInlineSegments(next) });
    this.updatePublishState(next);
    this.afterEdit();
  },

  // The server takes a club section only from its own club, posting as the
  // club; any identity may post elsewhere.
  clubFitsSection(club, section) {
    if (!section || section.sectionType !== 'club') return true;
    return Boolean(club && club.sectionId && club.sectionId === section.sectionId);
  },

  setClubIdentity(index) {
    const club = index >= 0 ? this.data.clubs[index] : null;
    const section = this.data.sectionIndex >= 0 ? this.data.sections[this.data.sectionIndex] : null;
    const keepSection = this.clubFitsSection(club, section);
    this.setData({
      clubIdentityIndex: index,
      clubIdentityLabel: club ? (club.name || club.clubName || '社团') : '以个人身份',
      clubIdentityOpen: false,
      ...(keepSection ? {} : { sectionIndex: -1 })
    });
    if (!keepSection) {
      wx.showToast({ title: '社团分区只能以该社团身份发布，已取消分区', icon: 'none' });
    }
    this.afterEdit();
  },

  chooseClubIdentity() {
    const names = ['以个人身份', ...this.data.clubs.map((club) => club.name || club.clubName || '社团')];
    wx.showActionSheet({
      itemList: names,
      success: (res) => this.setClubIdentity(res.tapIndex - 1)
    });
  },

  onContentInput(event) {
    const value = event.detail.value.slice(0, CONTENT_LIMIT);
    const cursor = typeof event.detail.cursor === 'number' ? event.detail.cursor : value.length;
    this.setData({
      content: value,
      contentLength: value.length,
      contentCursor: cursor,
      contentSegments: buildInlineSegments(value),
      canPublish: value.trim().length > 0 && !this.data.isPublishing
    });
    this.afterEdit();
  },

  onContentBlur(event) {
    if (typeof event.detail.cursor === 'number') {
      this.setData({ contentCursor: event.detail.cursor });
    }
  },

  toggleSectionSelector() {
    this.setData({
      sectionSelectorOpen: !this.data.sectionSelectorOpen,
      clubIdentityOpen: false,
      tagSelectorOpen: false,
      statusSelectorOpen: false,
      pinSelectorOpen: false,
      visibilitySelectorOpen: false
    });
  },

  onSectionTap(event) {
    const index = Number(event.currentTarget.dataset.index || 0);
    const section = this.data.sections[index];
    if (section && section.sectionType === 'college') {
      // 学院 comes from the school's identity mapping; it cannot be filled in.
      if (!this.data.userCollege) {
        wx.showModal({
          title: '学院未确认',
          content: '你的学院尚未由学校统一身份认证确认，暂时不能在学院分区发帖。',
          showCancel: false
        });
        return;
      }
      if (this.data.userCollege !== section.sectionName) {
        wx.showToast({ title: '只能在本学院分区发帖', icon: 'none' });
        return;
      }
    }
    if (section && section.sectionType === 'club' && this.data.sectionIndex !== index) {
      // A club section takes posts only from its own club, posting as the club.
      const clubIndex = this.data.clubs.findIndex((club) => club.sectionId
        && club.sectionId === section.sectionId);
      if (clubIndex < 0) {
        wx.showToast({ title: '社团分区仅允许负责人以社团身份发布', icon: 'none' });
        return;
      }
      const club = this.data.clubs[clubIndex];
      this.setData({ clubIdentityIndex: clubIndex, clubIdentityLabel: club.name || club.clubName || '社团' });
    }
    this.setData({
      sectionIndex: this.data.sectionIndex === index ? -1 : index,
      sectionSelectorOpen: false
    });
    this.afterEdit();
  },

  toggleClubIdentity() {
    this.setData({
      clubIdentityOpen: !this.data.clubIdentityOpen,
      sectionSelectorOpen: false,
      tagSelectorOpen: false,
      statusSelectorOpen: false,
      pinSelectorOpen: false,
      visibilitySelectorOpen: false
    });
  },

  onClubIdentityTap(event) {
    this.setClubIdentity(Number(event.currentTarget.dataset.index));
  },

  toggleTagSelector() {
    if (this.data.tagSelectorOpen) {
      this.setData({ tagSelectorOpen: false });
      return;
    }
    this.setData({
      customTagText: '',
      tagSelectorOpen: true,
      statusSelectorOpen: false,
      pinSelectorOpen: false,
      visibilitySelectorOpen: false
    });
  },

  onCustomTagInput(event) {
    this.setData({ customTagText: event.detail.value });
  },

  insertTag(event) {
    const tag = event.currentTarget.dataset.tag;
    if (!tag) return;
    this.insertInlineTag(tag);
  },

  addCustomTag() {
    const input = this.data.customTagText.trim();
    if (!input) return;
    const rows = input
      .split(/[,\s，\n]+/)
      .map((item) => item.trim())
      .filter(Boolean);
    if (!rows.length) return;
    rows.forEach((tag) => {
      this.insertInlineTag(tag);
    });
    this.setData({ customTagText: '' });
  },

  closeTagSelector() {
    this.setData({ tagSelectorOpen: false });
  },

  insertInlineTag(tag) {
    const cleanTag = String(tag || '').replace(/^#+/, '').trim();
    if (!cleanTag) return;
    const content = this.data.content;
    const cursor = Math.max(0, Math.min(this.data.contentCursor, content.length));
    const before = content.slice(0, cursor);
    const after = content.slice(cursor);
    const prefix = before && !/\s$/.test(before) ? ' ' : '';
    const suffix = after && !/^\s/.test(after) ? ' ' : '';
    const insertText = `${prefix}#${cleanTag} `;
    const nextContent = `${before}${insertText}${suffix}${after}`.slice(0, CONTENT_LIMIT);
    const nextCursor = Math.min(before.length + insertText.length, nextContent.length);
    this.setData({
      content: nextContent,
      contentLength: nextContent.length,
      contentCursor: nextCursor,
      contentSegments: buildInlineSegments(nextContent),
      canPublish: nextContent.trim().length > 0 && !this.data.isPublishing
    });
    this.afterEdit();
  },

  toggleStatusSelector() {
    this.setData({
      statusSelectorOpen: !this.data.statusSelectorOpen,
      tagSelectorOpen: false,
      pinSelectorOpen: false,
      visibilitySelectorOpen: false
    });
  },

  onStatusTap(event) {
    const index = Number(event.currentTarget.dataset.index || 0);
    this.setData({
      postStatusIndex: index,
      selectedStatus: STATUS_OPTIONS[index],
      statusSelectorOpen: false
    });
    this.afterEdit();
  },

  togglePinSelector() {
    if (!this.data.isLevelOneUser) return;
    this.setData({
      pinSelectorOpen: !this.data.pinSelectorOpen,
      tagSelectorOpen: false,
      statusSelectorOpen: false,
      visibilitySelectorOpen: false
    });
  },

  onPinTap(event) {
    const index = Number(event.currentTarget.dataset.index || 0);
    this.setData({
      pinIndex: index,
      pinSelectorOpen: false
    });
  },

  toggleAnonymous() {
    const useAnonymousAlias = !this.data.useAnonymousAlias;
    this.setData({ useAnonymousAlias, anonymousAlias: '' });
    if (useAnonymousAlias) this.fillRandomAlias();
  },

  // 随机. Errors only matter when the user asked explicitly; on the automatic
  // fill the field stays empty and the server falls back to 匿名同学.
  async fillRandomAlias(event) {
    const explicit = Boolean(event && event.currentTarget);
    try {
      const alias = await getRandomAnonymousAlias();
      if (this.data.useAnonymousAlias) this.setData({ anonymousAlias: alias });
    } catch (error) {
      if (explicit) wx.showToast({ title: '随机昵称获取失败', icon: 'none' });
    }
  },

  onAnonymousAliasInput(event) {
    // Same limit as the server's sanitize_alias.
    this.setData({ anonymousAlias: event.detail.value.slice(0, 24) });
  },

  toggleVisibilitySelector() {
    this.setData({
      visibilitySelectorOpen: !this.data.visibilitySelectorOpen,
      tagSelectorOpen: false,
      statusSelectorOpen: false,
      pinSelectorOpen: false
    });
  },

  onVisibilityTap(event) {
    const value = event.currentTarget.dataset.value;
    this.setData({
      privateOnly: value === 'private',
      visibilitySelectorOpen: false
    });
  },

  chooseImages() {
    const remain = MAX_IMAGE_COUNT - this.data.images.length;
    if (remain <= 0) return;
    const handlePicked = (files) => {
      const rows = files
        .map((file) => ({
          localPath: file.tempFilePath || file.path || '',
          size: Number(file.size || 0)
        }))
        .filter((file) => file.localPath)
        .slice(0, remain);
      if (!rows.length) return;
      const nextImages = [
        ...this.data.images,
        ...rows.map((file) => ({
          localPath: file.localPath,
          size: file.size,
          uploading: false,
          uploadedId: '',
          url: ''
        }))
      ];
      this.setData({ images: nextImages });
      this.uploadPendingImages().catch((error) => {
        wx.showToast({
          title: (error && error.data && error.data.message) || '图片上传失败',
          icon: 'none'
        });
      });
    };

    if (wx.chooseMedia) {
      wx.chooseMedia({
        count: remain,
        mediaType: ['image'],
        sizeType: ['compressed'],
        sourceType: ['album', 'camera'],
        success: (res) => handlePicked(res.tempFiles || [])
      });
      return;
    }

    wx.chooseImage({
      count: remain,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: (res) => {
        const paths = res.tempFilePaths || [];
        const tempFiles = res.tempFiles || [];
        handlePicked(
          paths.map((path, index) => ({
            tempFilePath: path,
            size: Number((tempFiles[index] && tempFiles[index].size) || 0)
          }))
        );
      }
    });
  },

  previewImage(event) {
    const current = event.currentTarget.dataset.path;
    const urls = this.data.images.map((item) => item.localPath);
    if (current && urls.length) {
      wx.previewImage({ current, urls });
    }
  },

  removeImage(event) {
    const index = Number(event.currentTarget.dataset.index || 0);
    const images = this.data.images.slice();
    images.splice(index, 1);
    this.setData({ images });
  },

  async uploadPendingImages() {
    if (this.data.isUploading) return;
    const pending = this.data.images.filter((item) => !item.uploadedId);
    if (!pending.length) return;

    this.setData({ isUploading: true });
    const images = this.data.images.slice();
    try {
      for (let index = 0; index < images.length; index += 1) {
        if (images[index].uploadedId) continue;
        images[index] = { ...images[index], uploading: true };
        this.setData({ images });
        const uploaded = await uploadPostImage(images[index].localPath);
        images[index] = {
          ...images[index],
          uploading: false,
          uploadedId: uploaded.id || '',
          url: uploaded.url || ''
        };
        this.setData({ images });
      }
    } catch (error) {
      const resetImages = images.map((item) => ({ ...item, uploading: false }));
      this.setData({ images: resetImages });
      throw error;
    } finally {
      this.setData({ isUploading: false });
    }
  },

  async submitPost() {
    if (this.data.isPublishing) return;
    const check = this.validate();
    if (check.errorCount) {
      this.setData({ ...check, showErrors: true });
      wx.pageScrollTo({ scrollTop: 0, duration: 200 });
      return;
    }
    const content = this.data.content.trim();
    const tags = extractInlineTags(this.data.title, content);
    if (tags.length > TAG_LIMIT) {
      wx.showToast({ title: `话题最多 ${TAG_LIMIT} 个，当前 ${tags.length} 个`, icon: 'none' });
      return;
    }

    this.setData({ isPublishing: true, canPublish: false });
    wx.showLoading({ title: '发布中' });
    try {
      await this.uploadPendingImages();
      const uploadedImageIds = this.data.images
        .map((item) => item.uploadedId)
        .filter(Boolean);
      const pinMinutes = PIN_OPTIONS[this.data.pinIndex].minutes;
      const anonymousAlias = this.data.anonymousAlias.trim();
      const selectedSection = this.data.sectionIndex >= 0 ? this.data.sections[this.data.sectionIndex] : null;
      const payload = {
        title: this.data.title.trim(),
        content,
        contentFormat: this.data.markdown ? 'markdown' : 'plain',
        markdownSource: this.data.markdown ? content : undefined,
        sectionType: selectedSection ? selectedSection.sectionType : '',
        sectionId: selectedSection ? selectedSection.sectionId : '',
        sectionName: selectedSection ? selectedSection.sectionName : '',
        publisherType: this.data.clubIdentityIndex >= 0 ? 'club' : 'user',
        publisherClubId: this.data.clubIdentityIndex >= 0 && this.data.clubs[this.data.clubIdentityIndex] ? this.data.clubs[this.data.clubIdentityIndex].id : '',
        tags,
        allowComment: true,
        allowDm: !this.data.useAnonymousAlias,
        visibility: this.data.privateOnly ? 'private' : 'public',
        hasImage: this.data.images.length > 0,
        imageUploadIds: uploadedImageIds,
        useAnonymousAlias: this.data.useAnonymousAlias
      };

      if (this.data.postStatusIndex >= 0) {
        payload.status = STATUS_OPTIONS[this.data.postStatusIndex].value;
      }
      if (pinMinutes != null && pinMinutes > 0) {
        payload.pinDurationMinutes = pinMinutes;
      }
      if (this.data.useAnonymousAlias && anonymousAlias) {
        payload.anonymousAlias = anonymousAlias;
      }

      const createdPost = await createPost(payload);
      if (!createdPost.id) {
        throw new Error('发布响应缺少帖子 ID');
      }
      wx.hideLoading();
      clearTimeout(this._draftTimer);
      wx.removeStorageSync(DRAFT_KEY);
      const isCampus = payload.sectionType === 'college';
      wx.showToast({ title: isCampus ? '已发布到校园' : '已悄悄放进树洞', icon: 'success' });
      setTimeout(() => {
        wx.navigateBack();
      }, 250);
    } catch (error) {
      wx.hideLoading();
      const responseData = error && error.data;
      const errorMessage = (responseData && responseData.message) || '发布失败，请重试';
      const errorCode = responseData && responseData.data && responseData.data.code;
      if (errorCode === 'POST_CONTENT_REJECTED') {
        wx.showModal({
          title: '发布被自动审核拦截',
          content: errorMessage,
          showCancel: false,
          confirmText: '知道了'
        });
      } else {
        wx.showToast({ title: errorMessage, icon: 'none' });
      }
      this.setData({ isPublishing: false }, () => {
        this.updatePublishState();
      });
    }
  },

  confirmDiscard() {
    if (
      !this.data.title.trim() &&
      !this.data.content.trim() &&
      !this.data.images.length
    ) {
      wx.navigateBack();
      return;
    }
    // Nothing is lost: the draft is saved and restored next time.
    clearTimeout(this._draftTimer);
    this.saveDraft();
    wx.navigateBack();
  }
});
