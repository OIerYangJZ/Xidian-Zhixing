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

// Places with schematic x / y (percent of the plate) get a pin.
const isCoord = (value) => value !== '' && value !== null && value !== undefined
  && Number(value) >= 0 && Number(value) <= 100;

const pinsOf = (group) => ((group && group.items) || [])
  .map((item, index) => ({ name: item.name, index, x: item.x, y: item.y }))
  .filter((pin) => isCoord(pin.x) && isCoord(pin.y))
  // Near the top edge the name goes under the pin so it is not clipped.
  .map((pin) => ({ ...pin, below: Number(pin.y) < 25 }));

Page({
  data: {
    maps: [],
    activeIndex: 0,
    activeGroup: null,
    activePins: [],
    activePlace: -1,
    places: [],
    officialUrl: '',
    loading: true,
    errorMessage: ''
  },

  async onLoad() {
    await this.loadData();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  async loadData() {
    this.setData({ loading: true, errorMessage: '' });
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
      this.showGroup(Math.min(this.data.activeIndex, Math.max(maps.length - 1, 0)));
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '地图索引加载失败，请重试'
      });
    }
  },

  retryLoad() {
    this.loadData();
  },

  selectGroup(event) {
    this.showGroup(Number(event.currentTarget.dataset.index) || 0);
  },

  showGroup(index) {
    const group = this.data.maps[index] || null;
    this.setData({
      activeIndex: index,
      activeGroup: group,
      activePins: pinsOf(group),
      activePlace: -1
    });
  },

  selectPlace(event) {
    const index = Number(event.currentTarget.dataset.index);
    this.setData({ activePlace: this.data.activePlace === index ? -1 : index });
  },

  // The chosen index's own navigation link, else the first one configured.
  openOfficialMap() {
    const group = this.data.activeGroup;
    const url = (group && group.officialUrl) || this.data.officialUrl;
    if (!url) {
      wx.showToast({ title: '官方地图入口未配置', icon: 'none' });
      return;
    }
    openAppTarget({ url });
  }
});
