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
    statusText: '正在读取服务器 AI 状态',
    statusTone: 'neutral'
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
      statusText: '正在读取服务器 AI 状态',
      statusTone: 'neutral'
    });
    try {
      const status = await fetchAiModels();
      this.setData({
        configured: Boolean(status.configured),
        model: status.model || '',
        models: status.models || [],
        modelsText: (status.models || []).join('、'),
        statusText: status.configured ? '服务器 AI 已启用' : '服务器 AI 尚未配置',
        statusTone: status.configured ? 'success' : 'warning'
      });
    } catch (error) {
      this.setData({ configured: false, statusText: '无法读取服务器 AI 状态，请刷新重试', statusTone: 'danger' });
    } finally {
      this.setData({ loading: false });
    }
  }
});
