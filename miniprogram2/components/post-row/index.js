import { compactCount } from '../../utils/compact_count';
import { togglePostRepost } from '../../api/posts';

Component({
  properties: {
    item: { type: Object, value: {} },
    index: { type: Number, value: 0 },
    showFollowDot: { type: Boolean, value: false },
    listKey: { type: String, value: '' },
    previewImages: { type: Boolean, value: false }
  },

  data: { counts: { likes: '0', comments: '0', reposts: '0', favorites: '0', views: '0' } },

  observers: {
    'item.**'(item) {
      this.setData({ counts: {
        likes: compactCount(item.likeCount || 0),
        comments: compactCount(item.commentCount || 0),
        reposts: compactCount(item.repostCount || 0),
        favorites: compactCount(item.favoriteCount || 0),
        views: compactCount(item.viewCount || 0)
      } });
    }
  },

  methods: {
    stopTap() {},

    showOptions() {
      wx.showActionSheet({
        itemList: [this.data.item.favorited || this.data.item.isFavorited ? '取消收藏' : '收藏帖子', '查看详情'],
        success: ({ tapIndex }) => {
          if (tapIndex === 0) this.toggleFavorite();
          if (tapIndex === 1) this.openPost();
        }
      });
    },

    openPost() {
      this.triggerEvent('open', { id: this.data.item.id });
    },

    openReply() {
      this.triggerEvent('open', { id: this.data.item.id, focusReply: true });
    },

    openAuthor(event) {
      this.triggerEvent('author', event.currentTarget.dataset);
    },

    openTag(event) {
      this.triggerEvent('tag', { tag: event.currentTarget.dataset.tag });
    },

    openImage(event) {
      this.triggerEvent('image', {
        index: this.data.index,
        url: event.currentTarget.dataset.url,
        listKey: this.data.listKey
      });
    },

    toggleLike() {
      this.triggerEvent('like', { index: this.data.index, listKey: this.data.listKey });
    },

    async toggleRepost() {
      const item = this.data.item || {};
      if (!item.id || this._reposting) return;
      this._reposting = true;
      try {
        const reposted = Boolean(item.isReposted);
        const result = await togglePostRepost(item.id, reposted);
        const nextReposted = Boolean(result.reposted);
        this.setData({
          'item.isReposted': nextReposted,
          'item.repostCount': Math.max(0, Number(item.repostCount || 0) + (nextReposted ? 1 : -1)),
          'counts.reposts': compactCount(Math.max(0, Number(item.repostCount || 0) + (nextReposted ? 1 : -1)))
        });
      } catch (error) {
      } finally {
        this._reposting = false;
      }
    },

    toggleFavorite() {
      this.triggerEvent('favorite', { index: this.data.index, listKey: this.data.listKey });
    }
  }
});
