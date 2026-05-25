import { getCampusMaps } from '../../../api/campus';

Page({
  data: {
    maps: []
  },
  async onLoad() {
    const response = await getCampusMaps();
    this.setData({ maps: response.data || response || [] });
  }
});
