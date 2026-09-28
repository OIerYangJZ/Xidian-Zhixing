import { getUserInfo } from '../../../api/auth';
import {
  blockConversationPeer,
  getConversations,
  getConversationMessages,
  recallMessage as recallConversationMessage,
  sendConversationMessage,
  unblockConversationPeer
} from '../../../api/messages';
import { avatarInitial } from '../../../utils/format';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const RECALL_WINDOW_SECONDS = 120;
// The server refuses a message over 1000 characters; a forward adds its prefix.
const MESSAGE_MAX_CHARS = 1000;
const FORWARD_PREFIX = '[转发] ';

// wx.request rejects with the response ({ statusCode, data }) or a fail object ({ errMsg }).
const errorText = (error) => (error && error.data && error.data.message) || (error && error.errMsg) || '网络异常';

// How often an open chat looks for new messages.
const POLL_INTERVAL_MS = 8000;

Page({
  data: {
    conversationId: '',
    peerUserId: '',
    peerAvatar: '',
    peerName: '',
    peerInitial: '',
    myUserId: '',
    myAvatar: '',
    myInitial: '',
    messages: [],
    messageItems: [],
    content: '',
    loading: true,
    errorMessage: '',
    sending: false,
    blockedByMe: false,
    blockedByPeer: false,
    // No message requests: before the peer has written, one first message
    // is all I can send (handoff H4). A reply the peer since recalled still
    // comes back as a recalled placeholder, so it counts too.
    openedByPeer: false,
    serverSaysWait: false,
    showFirstNote: false,
    awaitingReply: false,
    replyToId: '',
    replyToContent: '',
    replyToSender: '',
    selectedMessageIds: [],
    selectMode: false,
    showForwardPicker: false,
    navTop: 44,
    navHeight: 32,
    recallableCount: 0,
    forwardTargets: []
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    const conversationId = options.id || '';
    const peerName = options.name ? decodeURIComponent(options.name) : '私信';
    const peerAvatar = options.peerAvatar ? decodeURIComponent(options.peerAvatar) : '';
    const peerUserId = options.peerUserId || '';
    const blockedByMe = options.blockedByMe === '1';
    const blockedByPeer = options.blockedByPeer === '1';
    wx.setNavigationBarTitle({ title: peerName });
    this.setData({
      conversationId,
      peerUserId,
      peerAvatar,
      peerName,
      peerInitial: avatarInitial(peerName),
      blockedByMe,
      blockedByPeer
    });
    this.loadCurrentUser();
    if (conversationId) this.loadMessages();
  },

  onShow() {
    const app = getApp();
    this.setData({ navTop: app.globalData.navTop || 44, navHeight: app.globalData.navHeight || 32 });
    applyThemeAndLanguage(this);
    // Replies arrive while the chat is open (and while it was hidden).
    if (this._shownOnce) this.refreshMessages();
    this._shownOnce = true;
    this.startPolling();
  },

  onHide() {
    this.stopPolling();
  },

  onUnload() {
    this.stopPolling();
  },

  startPolling() {
    this.stopPolling();
    if (!this.data.conversationId) return;
    this._pollTimer = setInterval(() => this.refreshMessages(), POLL_INTERVAL_MS);
  },

  stopPolling() {
    if (this._pollTimer) clearInterval(this._pollTimer);
    this._pollTimer = null;
  },

  // A quiet reload: the server's messages plus those still sending or
  // failed here, applied only if something changed.  Skipped while the
  // user is selecting messages, so the list does not move under them.
  async refreshMessages() {
    if (!this.data.conversationId || this.data.loading || this.data.selectMode || this._refreshing) return;
    this._refreshing = true;
    try {
      const [messages, conversations] = await Promise.all([
        getConversationMessages(this.data.conversationId),
        getConversations().catch(() => null)
      ]);
      const local = this.data.messages.filter((item) => ['sending', 'failed'].includes(item.deliveryStatus));
      const next = messages.concat(local);
      const signature = (list) => list.map((item) => `${item.id}:${item.recalled ? 1 : 0}:${item.deliveryStatus || ''}`).join('|');
      if (signature(next) === signature(this.data.messages)) return;
      const conversation = (conversations || []).find((item) => item.id === this.data.conversationId);
      const peerWrote = messages.some((item) => !item.fromMe);
      const hadPeerMessages = this.data.messages.filter((item) => !item.fromMe).length;
      this.setData({
        openedByPeer: this.data.openedByPeer || peerWrote,
        ...(conversation ? {
          blockedByMe: Boolean(conversation.blockedByMe),
          blockedByPeer: Boolean(conversation.blockedByPeer),
          serverSaysWait: Boolean(conversation.awaitingReply)
        } : {})
      });
      this.setMessages(next);
      if (messages.filter((item) => !item.fromMe).length > hadPeerMessages) this.scrollToBottom();
    } catch (error) {
      // Polling is best-effort; the next tick tries again.
    } finally {
      this._refreshing = false;
    }
  },

  async loadCurrentUser() {
    try {
      const response = await getUserInfo();
      const user = response && response.data ? response.data : null;
      if (!user) return;
      this.setData({
        myUserId: user.id,
        myAvatar: user.avatarUrl || '',
        myInitial: avatarInitial(user.nickname || user.alias || '我')
      });
    } catch (error) {}
  },

  async loadMessages() {
    this.setData({ loading: true, errorMessage: '' });
    try {
      // The list carries this chat's flags whichever page opened it.
      const [messages, conversations] = await Promise.all([
        getConversationMessages(this.data.conversationId),
        getConversations().catch(() => null)
      ]);
      const conversation = (conversations || [])
        .find((item) => item.id === this.data.conversationId);
      const peerWrote = messages.some((item) => !item.fromMe);
      const flags = conversation
        ? {
            blockedByMe: Boolean(conversation.blockedByMe),
            blockedByPeer: Boolean(conversation.blockedByPeer),
            openedByPeer: peerWrote,
            serverSaysWait: Boolean(conversation.awaitingReply)
          }
        : { openedByPeer: peerWrote, serverSaysWait: false };
      this.setData({ ...flags, loading: false });
      this.setMessages(messages);
      this.scrollToBottom();
    } catch (error) {
      this.setData({
        loading: false,
        errorMessage: (error && error.data && error.data.message)
          || (error && error.message)
          || '消息加载失败，请重试'
      });
    }
  },

  retryLoadMessages() {
    this.loadMessages();
  },

  buildMessageItems(messages) {
    const items = [];
    let lastTime = null;
    messages.forEach((message, index) => {
      const messageTime = this.parseMessageTime(message.createdAt);
      if (lastTime === null || messageTime - lastTime > 5 * 60 * 1000) {
        items.push({
          type: 'time',
          id: `time-${message.id}`,
          label: this.formatTimeLabel(messageTime)
        });
        lastTime = messageTime;
      }
      const decorated = this.decorateMessage(message);
      decorated.index = index;
      items.push({
        type: 'message',
        id: message.id,
        index,
        message: decorated
      });
    });
    return items;
  },

  decorateMessage(message) {
    const createdAt = message.createdAt || '';
    const isRecalled = Boolean(message.recalled || message.deliveryStatus === 'recalled');
    const deliveryStatus = message.deliveryStatus || (isRecalled ? 'recalled' : 'sent');
    return {
      ...message,
      // The server sends a recalled message without its content.
      content: isRecalled ? (message.fromMe ? '你撤回了一条消息' : '对方撤回了一条消息') : message.content,
      deliveryStatus,
      isRecalled,
      hasReplyContent: Boolean(message.hasReply || message.replyToContent),
      canRecall: this.canRecallMessage(message),
      // Mine carry 已读 / 未读 (handoff H1, H4).
      displayTime: deliveryStatus === 'failed'
        ? this.formatShortTime(createdAt)
        : deliveryStatus === 'sending'
          ? '发送中'
          : `${this.formatShortTime(createdAt)}${message.fromMe && !isRecalled ? ` · ${message.isRead ? '已读' : '未读'}` : ''}`,
      dimmed: this.data.selectMode && !this.canRecallMessage(message),
      selected: this.data.selectedMessageIds.includes(message.id)
    };
  },

  parseMessageTime(value) {
    const parsed = Date.parse(value || '');
    return Number.isNaN(parsed) ? Date.now() : parsed;
  },

  formatShortTime(value) {
    const time = new Date(this.parseMessageTime(value));
    const hh = String(time.getHours()).padStart(2, '0');
    const mm = String(time.getMinutes()).padStart(2, '0');
    return `${hh}:${mm}`;
  },

  formatTimeLabel(timestamp) {
    const time = new Date(timestamp);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
    const day = new Date(time.getFullYear(), time.getMonth(), time.getDate());
    const hh = String(time.getHours()).padStart(2, '0');
    const mm = String(time.getMinutes()).padStart(2, '0');
    if (day.getTime() === today.getTime()) {
      return `今天 ${hh}:${mm}`;
    }
    if (day.getTime() === yesterday.getTime()) {
      return `昨天 ${hh}:${mm}`;
    }
    return `${time.getMonth() + 1}/${time.getDate()} ${hh}:${mm}`;
  },

  canRecallMessage(message) {
    if (!message || !message.fromMe) return false;
    if (message.deliveryStatus === 'failed') return false;
    if (message.canRecall === false) return false;
    // The server's canRecall was computed when the list loaded; the window
    // keeps closing while the chat stays open.
    const createdAt = Date.parse(message.createdAt || '');
    if (Number.isNaN(createdAt)) return false;
    return (Date.now() - createdAt) / 1000 <= RECALL_WINDOW_SECONDS;
  },

  rebuildMessageItems() {
    const selected = this.data.messages.filter((m) => this.data.selectedMessageIds.includes(m.id));
    this.setData({
      messageItems: this.buildMessageItems(this.data.messages),
      recallableCount: selected.filter((m) => this.canRecallMessage(m)).length
    });
  },

  goBack() {
    if (getCurrentPages().length > 1) wx.navigateBack();
    else wx.switchTab({ url: '/pages/messages/index' });
  },

  selectAll() {
    const ids = this.data.messages
      .filter((m) => !m.isRecalled && m.deliveryStatus !== 'recalled' && m.deliveryStatus !== 'failed')
      .map((m) => m.id);
    const all = ids.length > 0 && ids.every((id) => this.data.selectedMessageIds.includes(id));
    this.setData({ selectedMessageIds: all ? [] : ids });
    this.rebuildMessageItems();
  },

  forwardSelected() {
    const messages = this.data.messages.filter((m) => this.data.selectedMessageIds.includes(m.id));
    if (messages.length) this.openForwardPicker(messages);
  },

  setMessages(nextMessages) {
    this.setData({
      messages: nextMessages,
      messageItems: this.buildMessageItems(nextMessages),
      ...this.firstMessageState(nextMessages)
    });
  },

  // Before the peer has written: a note, and once my one message is out
  // (not failed, not recalled), the locked input.
  firstMessageState(messages, serverSaysWait = this.data.serverSaysWait) {
    const beforeReply = !this.data.openedByPeer && !messages.some((item) => !item.fromMe);
    const mineOut = messages.some((item) => item.fromMe
      && !['failed', 'sending', 'recalled'].includes(item.deliveryStatus)
      && !item.recalled);
    return {
      showFirstNote: beforeReply,
      awaitingReply: beforeReply && (serverSaysWait || mineOut)
    };
  },

  updateMessage(messageId, updater) {
    const nextMessages = this.data.messages.map(message => {
      if (message.id !== messageId) return message;
      return updater({ ...message });
    });
    this.setMessages(nextMessages);
  },

  appendMessage(message) {
    const nextMessages = this.data.messages.concat(message);
    this.setMessages(nextMessages);
  },

  replaceMessage(localId, nextMessage) {
    const nextMessages = this.data.messages.map(message => (
      message.id === localId ? nextMessage : message
    ));
    this.setMessages(nextMessages);
  },

  async onInput(event) {
    this.setData({ content: event.detail.value });
  },

  openPeerProfile() {
    if (!this.data.peerUserId) return;
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${this.data.peerUserId}` });
  },

  openMyProfile() {
    if (!this.data.myUserId) return;
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${this.data.myUserId}` });
  },

  onMessageTap(event) {
    const index = Number(event.currentTarget.dataset.index);
    const message = this.data.messages[index];
    if (!message) return;
    if (this.data.selectMode) {
      this.toggleSelect(message.id);
    }
  },

  onMessageLongPress(event) {
    const index = Number(event.currentTarget.dataset.index);
    const message = this.data.messages[index];
    if (!message) return;
    if (this.data.selectMode) {
      this.toggleSelect(message.id);
      return;
    }

    const items = ['回复', '复制', '详情'];
    if (message.fromMe && this.canRecallMessage(message)) {
      items.push('撤回');
    }
    items.push('转发');
    items.push('多选');

    wx.showActionSheet({
      itemList: items,
      success: async (res) => {
        const action = items[res.tapIndex];
        if (action === '回复') {
          this.setData({
            replyToId: message.id,
            replyToContent: message.content || '',
            replyToSender: message.fromMe ? '我' : (message.senderAlias || '对方')
          });
        } else if (action === '复制') {
          wx.setClipboardData({ data: message.content || '' });
        } else if (action === '详情') {
          wx.showModal({
            title: '消息详情',
            content: this.buildMessageDetail(message),
            showCancel: false
          });
        } else if (action === '撤回') {
          await this.recallSingleMessage(message.id);
        } else if (action === '转发') {
          await this.openForwardPicker(message);
        } else if (action === '多选') {
          this.enterSelectMode(message.id);
        }
      }
    });
  },

  buildMessageDetail(message) {
    const lines = [
      `发送时间：${message.createdAt || ''}`,
      `发送方：${message.fromMe ? '我' : (message.senderAlias || '对方')}`,
      `状态：${message.deliveryStatus === 'recalled' || message.recalled ? '已撤回' : '正常'}`
    ];
    if (!message.fromMe && message.isRead) {
      lines.push('已读状态：已读');
    }
    if (message.hasReply || message.replyToContent) {
      lines.push(`回复：${message.replyToSender || '对方'} / ${message.replyToContent || ''}`);
    }
    return lines.join('\n');
  },

  clearReply() {
    this.setData({
      replyToId: '',
      replyToContent: '',
      replyToSender: ''
    });
  },

  async sendMessage() {
    const content = this.data.content.trim();
    if (!content || this.data.sending) return;
    const replyTarget = this.data.replyToId
      ? {
          id: this.data.replyToId,
          senderAlias: this.data.replyToSender,
          content: this.data.replyToContent
        }
      : null;
    const tempId = `temp-${Date.now()}`;
    const tempMessage = {
      id: tempId,
      content,
      createdAt: new Date().toISOString(),
      timeText: '刚刚',
      fromMe: true,
      senderAlias: '我',
      isRead: false,
      readAt: '',
      deliveryStatus: 'sending',
      canRecall: true,
      replyToId: replyTarget ? replyTarget.id : '',
      replyToSender: replyTarget ? replyTarget.senderAlias : '',
      replyToContent: replyTarget ? replyTarget.content : ''
    };
    this.setData({
      content: '',
      replyToId: '',
      replyToContent: '',
      replyToSender: '',
      sending: true
    });
    this.appendMessage(tempMessage);
    this.scrollToBottom();

    try {
      const sentMessage = await sendConversationMessage(this.data.conversationId, {
        content,
        replyToId: replyTarget ? replyTarget.id : ''
      });
      const finalMessage = this.decorateMessage({
        ...sentMessage,
        id: sentMessage.id || tempId,
        replyToId: sentMessage.replyToId || (replyTarget ? replyTarget.id : ''),
        replyToSender: sentMessage.replyToSender || (replyTarget ? replyTarget.senderAlias : ''),
        replyToContent: sentMessage.replyToContent || (replyTarget ? replyTarget.content : '')
      });
      this.replaceMessage(tempId, finalMessage);
    } catch (error) {
      const message = (error && error.data && error.data.message) || '';
      if (error && error.statusCode === 403 && message.includes('对方回复前')) {
        // Nothing was sent: drop the bubble and lock the input.
        const rest = this.data.messages.filter((item) => item.id !== tempId);
        this.setData({ serverSaysWait: true, content });
        this.setMessages(rest);
        wx.showToast({ title: message, icon: 'none' });
      } else {
        if (message) wx.showToast({ title: message, icon: 'none' });
        this.replaceMessage(tempId, {
          ...tempMessage,
          timeText: '发送失败',
          deliveryStatus: 'failed',
          canRecall: false
        });
      }
    }

    this.setData({ sending: false });
    this.scrollToBottom();
  },

  async retrySend(event) {
    const index = Number(event.currentTarget.dataset.index);
    const message = this.data.messages[index];
    if (!message || this.data.sending) return;
    const replyTarget = message.replyToId
      ? {
          id: message.replyToId,
          senderAlias: message.replyToSender || '对方',
          content: message.replyToContent || ''
        }
      : null;

    this.replaceMessage(message.id, {
      ...message,
      deliveryStatus: 'sending',
      timeText: '刚刚',
      canRecall: true
    });
    this.setData({ sending: true });

    try {
      const sentMessage = await sendConversationMessage(this.data.conversationId, {
        content: message.content,
        replyToId: replyTarget ? replyTarget.id : ''
      });
      const finalMessage = this.decorateMessage({
        ...sentMessage,
        id: sentMessage.id || message.id,
        replyToId: sentMessage.replyToId || (replyTarget ? replyTarget.id : ''),
        replyToSender: sentMessage.replyToSender || (replyTarget ? replyTarget.senderAlias : ''),
        replyToContent: sentMessage.replyToContent || (replyTarget ? replyTarget.content : '')
      });
      this.replaceMessage(message.id, finalMessage);
    } catch (error) {
      this.replaceMessage(message.id, {
        ...message,
        deliveryStatus: 'failed',
        timeText: '发送失败',
        canRecall: false
      });
    }

    this.setData({ sending: false });
  },

  async recallSingleMessage(messageId) {
    const message = this.data.messages.find(item => item.id === messageId);
    if (!message || (!message.canRecall && !this.canRecallMessage(message))) {
      wx.showToast({ title: '只能撤回 2 分钟内自己发送的消息', icon: 'none' });
      return;
    }
    try {
      await recallConversationMessage(this.data.conversationId, messageId);
      // A recalled first message frees the slot; firstMessageState rechecks
      // whether any of mine is still out.
      this.setData({ serverSaysWait: false });
      this.replaceMessage(messageId, {
        ...message,
        content: message.fromMe ? '你撤回了一条消息' : '对方撤回了一条消息',
        deliveryStatus: 'recalled',
        canRecall: false
      });
      if (this.data.replyToId === messageId) {
        this.clearReply();
      }
      wx.showToast({ title: '已撤回', icon: 'success' });
    } catch (error) {
      wx.showToast({ title: `撤回失败：${errorText(error)}`, icon: 'none' });
    }
  },

  async batchRecall() {
    const selectedMessages = this.data.messages.filter(message => this.data.selectedMessageIds.includes(message.id));
    const recallableMessages = selectedMessages.filter(message => this.canRecallMessage(message));
    if (!recallableMessages.length) {
      wx.showToast({ title: '只能撤回 2 分钟内自己发送的消息', icon: 'none' });
      return;
    }
    wx.showModal({
      title: '批量撤回',
      content: `确定撤回选中的 ${recallableMessages.length} 条消息吗？`,
      confirmText: '撤回',
      confirmColor: '#ff3b30',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          for (const message of recallableMessages) {
            await recallConversationMessage(this.data.conversationId, message.id);
          }
          const recalledIds = new Set(recallableMessages.map(message => message.id));
          const nextMessages = this.data.messages.map(message => {
            if (!recalledIds.has(message.id)) return message;
            return {
              ...message,
              content: message.fromMe ? '你撤回了一条消息' : '对方撤回了一条消息',
              deliveryStatus: 'recalled',
              canRecall: false
            };
          });
          this.setData({ serverSaysWait: false, selectMode: false, selectedMessageIds: [] });
          this.setMessages(nextMessages);
          if (this.data.replyToId && recalledIds.has(this.data.replyToId)) {
            this.clearReply();
          }
          wx.showToast({ title: `已撤回 ${recallableMessages.length} 条消息`, icon: 'success' });
        } catch (error) {
          wx.showToast({ title: `撤回失败：${errorText(error)}`, icon: 'none' });
        }
      }
    });
  },

  enterSelectMode(messageId) {
    this.setData({
      selectMode: true,
      selectedMessageIds: [messageId]
    });
    this.rebuildMessageItems();
  },

  toggleSelect(eventOrMessageId) {
    const messageId = typeof eventOrMessageId === 'string'
      ? eventOrMessageId
      : eventOrMessageId.currentTarget.dataset.messageId;
    if (!messageId) return;
    const selected = new Set(this.data.selectedMessageIds);
    if (selected.has(messageId)) {
      selected.delete(messageId);
    } else {
      selected.add(messageId);
    }
    const selectedMessageIds = Array.from(selected);
    // 多选 stays until 取消, as in handoff H2.
    this.setData({ selectedMessageIds });
    this.rebuildMessageItems();
  },

  exitSelectMode() {
    this.setData({
      selectMode: false,
      selectedMessageIds: []
    });
    this.rebuildMessageItems();
  },

  async openForwardPicker(message) {
    const messages = Array.isArray(message) ? message : [message];
    if (messages.some((item) => (FORWARD_PREFIX + (item.content || '')).length > MESSAGE_MAX_CHARS)) {
      wx.showToast({ title: `加上转发标记后超过 ${MESSAGE_MAX_CHARS} 字，无法转发`, icon: 'none' });
      return;
    }
    try {
      const conversations = await getConversations();
      const forwardTargets = conversations
        .filter(item => item.id !== this.data.conversationId && !item.blockedByMe && !item.blockedByPeer && !item.awaitingReply)
        .map(item => ({
          ...item,
          avatarInitial: avatarInitial(item.name || '')
        }));
      if (!forwardTargets.length) {
        wx.showToast({ title: '暂无可转发会话', icon: 'none' });
        return;
      }
      this._forwardMessages = messages;
      this.setData({
        showForwardPicker: true,
        forwardTargets
      });
    } catch (error) {
      wx.showToast({ title: `转发失败：${errorText(error)}`, icon: 'none' });
    }
  },

  closeForwardPicker() {
    this._forwardMessages = null;
    this.setData({
      showForwardPicker: false,
      forwardTargets: []
    });
  },

  async chooseForwardTarget(event) {
    const index = Number(event.currentTarget.dataset.index);
    const target = this.data.forwardTargets[index];
    const messages = this._forwardMessages;
    if (!target || !messages || !messages.length) return;
    try {
      // 逐条转发: one message after another, in order.
      for (const message of messages) {
        await sendConversationMessage(target.id, {
          content: `${FORWARD_PREFIX}${message.content || ''}`
        });
      }
      wx.showToast({ title: '已转发', icon: 'success' });
      this.closeForwardPicker();
      if (this.data.selectMode) this.exitSelectMode();
    } catch (error) {
      wx.showToast({ title: `转发失败：${errorText(error)}`, icon: 'none' });
    }
  },

  noop() {},

  async showOptionsSheet() {
    const actions = ['查看对方主页', this.data.blockedByMe ? '解除屏蔽' : '屏蔽对方'];
    wx.showActionSheet({
      itemList: actions,
      success: async (res) => {
        if (actions[res.tapIndex] === '查看对方主页') this.openPeerProfile();
        else await this.confirmToggleBlock();
      }
    });
  },

  async confirmToggleBlock() {
    const isBlocking = !this.data.blockedByMe;
    wx.showModal({
      title: isBlocking ? '屏蔽对方' : '解除屏蔽',
      content: isBlocking
        ? '确定要屏蔽对方吗？屏蔽后对方将无法给你发送消息。'
        : '确定要解除屏蔽吗？解除后对方可以继续给你发消息。',
      confirmText: isBlocking ? '屏蔽' : '解除屏蔽',
      confirmColor: '#ff3b30',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          if (isBlocking) {
            await blockConversationPeer(this.data.conversationId);
          } else {
            await unblockConversationPeer(this.data.conversationId);
          }
          this.setData({ blockedByMe: isBlocking });
          wx.showToast({ title: isBlocking ? '已屏蔽对方' : '已解除屏蔽', icon: 'success' });
        } catch (error) {
          wx.showToast({ title: `操作失败：${errorText(error)}`, icon: 'none' });
        }
      }
    });
  },

  scrollToBottom() {
    setTimeout(() => {
      wx.pageScrollTo({
        scrollTop: 999999,
        duration: 160
      });
    }, 50);
  }
});
