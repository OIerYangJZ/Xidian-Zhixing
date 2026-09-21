import { fetchAiModels } from '../../../api/ai';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    configured: false,
    model: '',
    models: [],
    modelsText: '',
    loading: false,
    statusText: '正在读取 AI 状态'
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.refresh();
  },

  async refresh() {
    if (this.data.loading) return;
    this.setData({
      loading: true,
      configured: false,
      model: '',
      models: [],
      modelsText: '',
      statusText: '正在读取 AI 状态'
    });
    try {
      const status = await fetchAiModels();
      this.setData({
        configured: Boolean(status.configured),
        model: status.model || '',
        models: status.models || [],
        modelsText: (status.models || []).join('、'),
        statusText: status.configured ? 'AI 已启用' : 'AI 尚未启用'
      });
    } catch (error) {
      this.setData({ configured: false, statusText: '无法读取 AI 状态' });
    } finally {
      this.setData({ loading: false });
    }
  }
});
