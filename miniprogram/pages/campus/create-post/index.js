import { getUserInfo } from '../../../api/auth';
import { getSectionsTree } from '../../../api/campus';
import { getClubs } from '../../../api/clubs';
import { createPost } from '../../../api/posts';
import { uploadPostImage } from '../../../api/uploads';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const MAX_IMAGE_COUNT = 20;
const CONTENT_LIMIT = 2000;
const TITLE_LIMIT = 50;
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
const ALIAS_WORDS = ['神秘', '路过的', '隔壁的', '匿名的', '安静的', '好奇的', '悠闲的', '低调的'];
const ALIAS_NOUNS = ['同学', '路人', '学长', '学弟', '学妹', '小伙伴', '小伙伴', '小伙伴'];

function extractInlineTags(...values) {
  const tags = [];
  values.forEach((value) => {
    String(value || '').replace(/#([^\s#]{1,30})(?=\s)/g, (_, tag) => {
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

function generateAnonymousAlias() {
  const now = Date.now();
  const adj = ALIAS_WORDS[Math.floor(now / 13) % ALIAS_WORDS.length];
  const noun = ALIAS_NOUNS[Math.floor(now / 17) % ALIAS_NOUNS.length];
  return `${adj}${noun}`;
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
    content: '',
    contentLength: 0,
    contentCursor: 0,
    contentSegments: [],
    canPublish: false,

    tagSelectorOpen: false,
    customTagText: '',
    tagOptions: TAG_OPTIONS,

    statusOptions: STATUS_OPTIONS,
    postStatusIndex: -1,
    selectedStatus: null,
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
      if (!dedupedSections.some((item) => item.id === section.id || item.sectionName === section.sectionName)) {
        dedupedSections.push(section);
      }
    });
    this.setData({ sections: dedupedSections, sectionIndex: -1, loading: false });
  },

  async loadInitialData() {
    this.setData({ loadErrorMessage: '' });
    try {
      await Promise.all([
        this.loadSections(),
        this.loadClubs(),
        this.loadUserLevel()
      ]);
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
    const clubs = await getClubs();
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
    this.setData({ title: event.detail.value.slice(0, TITLE_LIMIT) });
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
      if (!this.data.userCollege) {
        wx.showModal({
          title: '完善学院信息',
          content: '学院分区仅允许本学院同学发布，请先在个人资料中填写学院。',
          confirmText: '去填写',
          success: (res) => {
            if (res.confirm) wx.navigateTo({ url: '/pages/profile/edit-profile/index' });
          }
        });
        return;
      }
      if (this.data.userCollege !== section.sectionName) {
        wx.showToast({ title: '只能在本学院分区发帖', icon: 'none' });
        return;
      }
    }
    this.setData({
      sectionIndex: this.data.sectionIndex === index ? -1 : index,
      sectionSelectorOpen: false
    });
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
    this.setData({
      clubIdentityIndex: Number(event.currentTarget.dataset.index),
      clubIdentityOpen: false
    });
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
    const nextIndex = this.data.postStatusIndex === index ? -1 : index;
    this.setData({
      postStatusIndex: nextIndex,
      selectedStatus: nextIndex >= 0 ? STATUS_OPTIONS[nextIndex] : null,
      statusSelectorOpen: false
    });
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
    this.setData({
      useAnonymousAlias,
      anonymousAlias: useAnonymousAlias ? generateAnonymousAlias() : ''
    });
  },

  onAnonymousAliasInput(event) {
    this.setData({ anonymousAlias: event.detail.value.slice(0, 20) });
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
    if (!this.data.canPublish || this.data.isPublishing) return;
    const content = this.data.content.trim();
    if (!content) {
      wx.showToast({ title: '请输入帖子内容', icon: 'none' });
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
      const tags = extractInlineTags(content).slice(0, 5);
      const selectedSection = this.data.sectionIndex >= 0 ? this.data.sections[this.data.sectionIndex] : null;
      const payload = {
        title: this.data.title.trim(),
        content,
        contentFormat: 'plain',
        sectionType: selectedSection ? selectedSection.sectionType : '',
        sectionId: selectedSection ? (selectedSection.sectionId || selectedSection.id) : '',
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
    wx.showModal({
      title: '放弃编辑？',
      content: '确定要放弃当前编辑内容吗？',
      cancelText: '取消',
      confirmText: '放弃',
      confirmColor: '#ff3b30',
      success: (res) => {
        if (res.confirm) {
          wx.navigateBack();
        }
      }
    });
  }
});
