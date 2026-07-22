import { fetchAiModels, getAiConfig } from '../../../api/ai';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    configured: false,
    model: '',
    models: [],
    modelsText: '',
    loading: false,
    statusText: '正在读取服务器 AI 状态'
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.refresh();
  },

  async refresh() {
    const cached = getAiConfig();
    this.setData({
      configured: Boolean(cached.configured),
      model: cached.model || '',
      models: cached.models || [],
      modelsText: (cached.models || []).join('、'),
      statusText: cached.configured ? '服务器 AI 已启用' : '服务器 AI 尚未配置'
    });
    if (this.data.loading) return;
    this.setData({ loading: true });
    try {
      const status = await fetchAiModels();
      this.setData({
        configured: Boolean(status.configured),
        model: status.model || '',
        models: status.models || [],
        modelsText: (status.models || []).join('、'),
        statusText: status.configured ? '服务器 AI 已启用' : '服务器 AI 尚未配置'
      });
    } catch (error) {
      this.setData({ configured: false, statusText: '无法读取服务器 AI 状态' });
    } finally {
      this.setData({ loading: false });
    }
  }
});
