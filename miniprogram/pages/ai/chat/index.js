import { fetchAiModels, sendAiMessage, newAiRequestId, cancelAiMessage } from '../../../api/ai';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { openAppTarget } from '../../../utils/navigation';

const normalizeAiReply = (response) => {
  const data = response && response.data ? response.data : response || {};
  return String(data.reply || data.answer || data.content || '').trim();
};

const normalizeReferences = (response) => {
  const data = response && response.data ? response.data : response || {};
  const rows = Array.isArray(data.citations) ? data.citations : (Array.isArray(data.references) ? data.references : []);
  return rows.map((item, index) => ({
    ...item,
    key: `${item.type || 'ref'}-${item.id || index}`,
    title: item.title || (item.type === 'post' || item.targetType === 'post' ? '相关帖子' : '基础资料')
  }));
};

const saveAiHistory = (question, answer, references = []) => {
  const row = {
    question,
    answer,
    references,
    createdAt: new Date().toISOString()
  };
  const rows = [row, ...(wx.getStorageSync('aiHistory') || [])]
    .filter((item) => item && item.question)
    .slice(0, 30);
  wx.setStorageSync('aiHistory', rows);
};

Page({
  data: {
    chatId: '',
    messages: [
      { id: '1', role: 'assistant', content: '你好，我是小电，西电知行平台智能助手。你可以问校园信息，也可以让我整理资料、检索电台里的公开讨论。' }
    ],
    inputVal: '',
    isSending: false,
    scrollTop: 0,
    configured: false,
    currentModel: '',
    configLoading: true,
    configError: ''
  },

  onLoad(options) {
    applyThemeAndLanguage(this);
    if (options.id) {
      this.setData({ chatId: options.id });
    }
    if (options.q || options.prefill) {
      this.setData({ inputVal: decodeURIComponent(options.q || options.prefill) });
    }
    if (options.answer) {
      this.setData({
        messages: [
          ...this.data.messages,
          { id: `answer-${Date.now()}`, role: 'assistant', content: decodeURIComponent(options.answer) }
        ]
      });
    }
    if (!requireLoginPage()) return;
    this._initializingConfig = true;
    this.refreshConfigState()
      .then(() => {
        if (this.data.inputVal && this.data.configured) {
          this._autoSendQueued = true;
          this.sendMessage();
        }
      })
      .finally(() => {
        this._initializingConfig = false;
      });
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    if (this._initializingConfig) return;
    this.refreshConfigState().then(() => {
      if (this.data.inputVal && this.data.messages.length === 1 && !this.data.isSending && !this._autoSendQueued && this.data.configured) {
        this._autoSendQueued = true;
        this.sendMessage();
      }
    });
  },

  onInput(e) {
    this.setData({ inputVal: e.detail.value });
  },

  async refreshConfigState() {
    this.setData({
      configured: false,
      currentModel: '',
      configLoading: true,
      configError: ''
    });
    try {
      const status = await fetchAiModels();
      this.setData({
        configured: Boolean(status.configured),
        currentModel: status.model || '',
        configLoading: false,
        configError: ''
      });
    } catch (error) {
      this.setData({
        configured: false,
        currentModel: '',
        configLoading: false,
        configError: 'AI 状态加载失败，请重试'
      });
    }
  },

  goSettings() {
    wx.navigateTo({ url: '/pages/profile/ai-settings/index' });
  },

  async sendMessage() {
    const text = this.data.inputVal.trim();
    if (!text || this.data.isSending) return;
    if (this.data.configLoading) {
      wx.showToast({ title: '正在读取 AI 状态', icon: 'none' });
      return;
    }
    if (this.data.configError) {
      wx.showToast({ title: 'AI 状态加载失败，请先重试', icon: 'none' });
      return;
    }
    if (!this.data.configured) {
      wx.showToast({ title: '服务器 AI 尚未配置', icon: 'none' });
      this.goSettings();
      return;
    }
    this._autoSendQueued = false;

    const newMsg = {
      id: Date.now().toString(),
      role: 'user',
      content: text
    };

    const requestId = newAiRequestId();
    this._activeRequestId = requestId;
    this.setData({
      messages: [...this.data.messages, newMsg],
      inputVal: '',
      isSending: true
    }, this.scrollToBottom);

    try {
      const historyMessages = this.data.messages
        .filter((item) => item.role === 'user' || item.role === 'assistant')
        .slice(-8)
        .map((item) => ({ role: item.role, content: item.content }));
      const res = await sendAiMessage(text, { messages: historyMessages, requestId });
      // Stopped while waiting: the user has moved on, drop the late answer.
      if (this._activeRequestId !== requestId) return;
      const reply = normalizeAiReply(res);
      const references = normalizeReferences(res);
      if (!reply) {
        throw new Error('AI 响应缺少回复内容');
      }
      const replyMsg = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: reply,
        references
      };
      this.setData({
        messages: [...this.data.messages, replyMsg]
      }, this.scrollToBottom);
      saveAiHistory(text, reply, references);
    } catch (err) {
      // A stopped request fails with 409 by design; that is not an error.
      if (this._activeRequestId !== requestId) return;
      this.setData({
        messages: [
          ...this.data.messages,
          {
            id: `error-${Date.now()}`,
            role: 'assistant',
            content: '本次请求失败，请稍后重试。'
          }
        ]
      }, this.scrollToBottom);
      wx.showToast({ title: 'AI 请求失败，请检查设置', icon: 'none' });
    } finally {
      if (this._activeRequestId === requestId) {
        this._activeRequestId = null;
        this.setData({ isSending: false });
      }
    }
  },

  // Stops the answer in progress. The server cancel is what stops the model
  // provider from generating; the input is released immediately either way.
  async stopMessage() {
    const requestId = this._activeRequestId;
    if (!requestId) return;
    this._activeRequestId = null;
    this.setData({ isSending: false });
    try {
      await cancelAiMessage(requestId);
    } catch (err) {
      wx.showToast({ title: '停止请求未送达，回答可能仍在生成', icon: 'none' });
    }
  },

  scrollToBottom() {
    wx.createSelectorQuery().select('.chat-list').boundingClientRect(res => {
      if (res) {
        this.setData({
          scrollTop: res.height + 9999
        });
      }
    }).exec();
  },

  openReference(event) {
    const messageIndex = Number(event.currentTarget.dataset.messageIndex);
    const referenceIndex = Number(event.currentTarget.dataset.referenceIndex);
    const message = this.data.messages[messageIndex];
    const reference = message && message.references ? message.references[referenceIndex] : null;
    if (!reference) return;
    if (!openAppTarget({ ...reference, url: reference.sourceUrl })) {
      wx.showToast({ title: '该来源暂无可打开页面', icon: 'none' });
    }
  }
});
