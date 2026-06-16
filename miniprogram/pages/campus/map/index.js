import { getCampusMaps } from '../../../api/campus';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { openAppTarget } from '../../../utils/navigation';

const buildPlaces = (maps = []) => {
  const rows = [];
  maps.forEach((group) => {
    (group.items || []).forEach((item, index) => {
      rows.push({
        ...item,
        id: `${group.id || 'map'}-${index}`,
        groupName: group.name,
        officialUrl: group.officialUrl || ''
      });
    });
  });
  return rows;
};

Page({
  data: {
    maps: [],
    places: [],
    officialUrl: '',
    loading: true
  },

  async onLoad() {
    await this.loadData();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const response = await getCampusMaps();
      const maps = response.data || response || [];
      const firstOfficial = maps.find((item) => item.officialUrl);
      this.setData({
        maps,
        places: buildPlaces(maps),
        officialUrl: firstOfficial ? firstOfficial.officialUrl : '',
        loading: false
      });
    } catch (error) {
      console.error(error);
      this.setData({ loading: false });
    }
  },

  openOfficialMap() {
    if (!this.data.officialUrl) {
      wx.showToast({ title: '官方地图入口未配置', icon: 'none' });
      return;
    }
    openAppTarget({ url: this.data.officialUrl });
  }
});
