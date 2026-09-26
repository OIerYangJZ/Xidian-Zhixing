import { getBlocks, unblockUserGlobally } from '../../../../api/user';
import { requireLoginPage } from '../../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../../utils/theme_i18n';

Page({
  data: {
    loading: true,
    blocks: [],
    errorMessage: ''
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadBlocks();
  },

  async loadBlocks() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      const blocks = await getBlocks();
      this.setData({ blocks, loading: false, errorMessage: '' });
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: '黑名单加载失败，请重试'
      });
    }
  },

  openUser(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
  },

  onUnblockTap(event) {
    const targetUserId = event.currentTarget.dataset.id;
    const nickname = event.currentTarget.dataset.nickname || '该用户';
    if (!targetUserId) return;

    wx.showModal({
      title: '解除屏蔽？',
      content: `解除后，「${nickname}」可以再次给你发消息。`,
      confirmText: '解除屏蔽',
      success: async (res) => {
        if (res.confirm) {
          try {
            await unblockUserGlobally(targetUserId);
            // 乐观更新，过滤掉已解除的用户
            const updatedBlocks = this.data.blocks.filter((b) => b.id !== targetUserId);
            this.setData({ blocks: updatedBlocks });
            wx.showToast({
              title: '已解除屏蔽',
              icon: 'success'
            });
          } catch (error) {
            console.error('[unblock error]', error);
          }
        }
      }
    });
  }
});
