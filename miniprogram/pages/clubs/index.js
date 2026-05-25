import { getClubs } from '../../api/clubs';

Page({
  data: { clubs: [] },
  async onLoad() {
    this.setData({ clubs: await getClubs() });
  },
  openDetail(event) {
    wx.navigateTo({ url: `/pages/clubs/detail/index?id=${event.currentTarget.dataset.id}` });
  },
  apply() {
    wx.navigateTo({ url: '/pages/clubs/apply/index' });
  }
});
