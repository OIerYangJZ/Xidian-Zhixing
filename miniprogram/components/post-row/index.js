Component({
  properties: {
    item: { type: Object, value: {} },
    index: { type: Number, value: 0 },
    showFollowDot: { type: Boolean, value: false },
    listKey: { type: String, value: '' },
    previewImages: { type: Boolean, value: false }
  },

  methods: {
    openPost() {
      this.triggerEvent('open', { id: this.data.item.id });
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

    toggleFavorite() {
      this.triggerEvent('favorite', { index: this.data.index, listKey: this.data.listKey });
    }
  }
});
