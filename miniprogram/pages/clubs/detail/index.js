import { getClubDetail } from '../../../api/clubs';

Page({
  data: { id: '', club: null },
  onLoad(options) {
    this.setData({ id: options.id || '' });
    this.loadDetail();
  },
  async loadDetail() {
    this.setData({ club: await getClubDetail(this.data.id) });
  }
});
