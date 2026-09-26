import { getUserInfo } from '../../../api/auth';
import { uploadAvatarImage, uploadBackgroundImage } from '../../../api/uploads';
import { updateProfile } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { avatarInitial } from '../../../utils/format';

Page({
  data: {
    loading: true,
    errorMessage: '',
    saving: false,
    uploadingAvatar: false,
    uploadingBackground: false,
    profile: null,
    form: {
      nickname: '',
      bio: '',
      gender: '',
      college: '',
      major: '',
      studentId: '',
      email: ''
    },
    avatarPreview: '',
    backgroundPreview: '',
    avatarInitial: '匿',
    genderOptions: [
      { value: '', label: '不显示' },
      { value: '男', label: '男' },
      { value: '女', label: '女' }
    ]
  },

  // Loaded once: wx.chooseImage leaves the page, and reloading on the way
  // back would throw away the new avatar / background and unsaved edits.
  onLoad() {
    if (!requireLoginPage()) return;
    this.loadProfile();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  async loadProfile() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const response = await getUserInfo();
      const profile = response.data || {};
      const nickname = profile.nickname || profile.alias || '';
      this.setData({
        profile,
        form: {
          nickname,
          bio: profile.bio || '',
          gender: profile.gender || '',
          college: profile.college || '',
          major: profile.major || '',
          studentId: profile.studentId || '',
          email: profile.email || ''
        },
        avatarPreview: profile.avatarUrl || '',
        backgroundPreview: profile.backgroundImageUrl || '',
        avatarInitial: avatarInitial(nickname || '匿'),
        loading: false,
        errorMessage: ''
      });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: '个人资料加载失败，请重试'
      });
    }
  },

  onFieldInput(event) {
    const key = event.currentTarget.dataset.key;
    if (!key) return;
    this.setData({ [`form.${key}`]: event.detail.value });
    if (key === 'nickname') {
      this.setData({
        avatarInitial: avatarInitial(event.detail.value.trim() || '匿')
      });
    }
  },

  onGenderTap(event) {
    this.setData({ 'form.gender': event.currentTarget.dataset.value || '' });
  },

  chooseAvatar() {
    if (this.data.uploadingAvatar) return;
    wx.chooseImage({
      count: 1,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: async (res) => {
        const tempPath = res.tempFilePaths[0];
        if (!tempPath) return;
        this.setData({ uploadingAvatar: true });
        wx.showLoading({ title: '上传中' });
        try {
          const uploadRes = await uploadAvatarImage(tempPath);
          this.setData({ avatarPreview: uploadRes.avatarUrl || this.data.avatarPreview });
        } catch (error) {
          wx.showToast({
            title: (error && error.data && error.data.message) || '头像上传失败',
            icon: 'none'
          });
        } finally {
          wx.hideLoading();
          this.setData({ uploadingAvatar: false });
        }
      }
    });
  },

  chooseBackground() {
    if (this.data.uploadingBackground) return;
    wx.chooseImage({
      count: 1,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: async (res) => {
        const tempPath = res.tempFilePaths[0];
        if (!tempPath) return;
        this.setData({ uploadingBackground: true });
        wx.showLoading({ title: '上传中' });
        try {
          const uploadRes = await uploadBackgroundImage(tempPath);
          this.setData({ backgroundPreview: uploadRes.url || '' });
        } catch (error) {
          wx.showToast({
            title: (error && error.data && error.data.message) || '背景图片上传失败',
            icon: 'none'
          });
        } finally {
          wx.hideLoading();
          this.setData({ uploadingBackground: false });
        }
      }
    });
  },

  clearBackground() {
    this.setData({ backgroundPreview: '' });
  },

  async saveProfile() {
    if (this.data.saving) return;
    const nickname = this.data.form.nickname.trim();
    const bio = this.data.form.bio.trim();
    if (!nickname) {
      wx.showToast({ title: '昵称不能为空', icon: 'none' });
      return;
    }
    if (bio.length > 100) {
      wx.showToast({ title: '个性签名不能超过100个字符', icon: 'none' });
      return;
    }
    this.setData({ saving: true });
    wx.showLoading({ title: '保存中' });
    try {
      await updateProfile({
        nickname,
        bio,
        gender: this.data.form.gender,
        college: this.data.form.college.trim(),
        major: this.data.form.major.trim(),
        avatarUrl: this.data.avatarPreview || '',
        backgroundImageUrl: this.data.backgroundPreview || ''
      });
      wx.hideLoading();
      wx.showToast({ title: '资料已保存', icon: 'success' });
      await this.loadProfile();
      setTimeout(() => {
        wx.navigateBack({ fail: () => wx.switchTab({ url: '/pages/profile/index' }) });
      }, 400);
    } catch (error) {
      wx.hideLoading();
    } finally {
      this.setData({ saving: false });
    }
  },

});
