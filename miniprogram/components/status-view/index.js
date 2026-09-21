Component({
  properties: {
    mode: { type: String, value: 'empty' },
    text: { type: String, value: '' },
    retryText: { type: String, value: '重新加载' },
    showRetry: { type: Boolean, value: false }
  },

  methods: {
    retry() {
      this.triggerEvent('retry');
    }
  }
});
