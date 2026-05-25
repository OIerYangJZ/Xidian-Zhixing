Page({
  data: {
    name: ''
  },
  onLoad(options) {
    this.setData({ name: decodeURIComponent(options.name || '校园服务') });
  }
});
