import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';
import '../profile/public_user_profile_page.dart';
import '../../models/conversation_item.dart';
import '../../models/direct_message_item.dart';
import '../../repositories/app_repositories.dart';
import '../../widgets/emoji/emoji_assistant_bar.dart';

typedef ConversationFlagsChanged =
    void Function({bool? blockedByMe, bool? blockedByPeer});

enum _MessageAction { copy, reply, recall }

/// One conversation (handoff W3 / H1 / H3): time separators, bubbles with
/// reply quotes, a menu per message (right-click or long-press), 发送失败 ·
/// 重发 on the failed bubble, and the blocked states in place of the input.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversation,
    this.onMessageSent,
    this.onConversationRead,
    this.onConversationRemoved,
    this.onConversationFlagsChanged,
    this.peerUserId,
    this.embedded = false,
  });

  final ConversationItem conversation;
  final ValueChanged<String>? onMessageSent;
  final VoidCallback? onConversationRead;
  final VoidCallback? onConversationRemoved;
  final ConversationFlagsChanged? onConversationFlagsChanged;

  /// Overrides [ConversationItem.peerUserId] for 查看主页.
  final String? peerUserId;

  /// Shown as the right pane of the wide conversations layout rather than as
  /// a pushed route, so there is no route of its own to pop.
  final bool embedded;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  /// A new time separator when this much time passes between messages.
  static const Duration _separatorGap = Duration(minutes: 10);

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  late ConversationItem _conversation;
  List<DirectMessageItem> _messages = const <DirectMessageItem>[];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _lastFailedContent;
  DirectMessageItem? _lastFailedReplyTarget;
  DirectMessageItem? _replyingTo;

  /// Messages recalled in this session, shown as 你撤回了一条消息 until the
  /// next load.
  final Set<String> _recalledIds = <String>{};

  String? get _peerId {
    final String id = widget.peerUserId ?? _conversation.peerUserId;
    return id.trim().isEmpty ? null : id;
  }

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _loadMessages();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final String? peerId = _peerId;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        titleSpacing: widget.embedded ? 20 : 0,
        title: Row(
          children: <Widget>[
            ZxAvatar(
              name: _conversation.nameFor(locale),
              imageUrl: _conversation.avatarUrl,
              size: 38,
              onTap: peerId == null ? null : () => _openProfile(peerId),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          _conversation.nameFor(locale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZxType.label.copyWith(color: t.text),
                        ),
                      ),
                      if (_conversation.blockedByMe) ...<Widget>[
                        const SizedBox(width: 6),
                        ZxBadge.blocked(
                          uiText(context, zh: '已屏蔽', en: 'Blocked'),
                        ),
                      ],
                    ],
                  ),
                  if (peerId != null)
                    InkWell(
                      key: const Key('chat-view-profile'),
                      onTap: () => _openProfile(peerId),
                      child: Text(
                        uiText(context, zh: '查看主页', en: 'View profile'),
                        style: ZxType.caption.copyWith(
                          color: t.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _loadMessages,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: uiText(context, zh: '刷新', en: 'Refresh'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: uiText(context, zh: '更多', en: 'More'),
            onSelected: (String value) {
              switch (value) {
                case 'profile':
                  if (peerId != null) _openProfile(peerId);
                case 'block':
                  _toggleBlock(true);
                case 'unblock':
                  _toggleBlock(false);
                case 'delete':
                  _deleteConversation();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              if (peerId != null)
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Text(
                    uiText(context, zh: '查看对方主页', en: 'View profile'),
                  ),
                ),
              PopupMenuItem<String>(
                value: _conversation.blockedByMe ? 'unblock' : 'block',
                child: Text(
                  _conversation.blockedByMe
                      ? uiText(context, zh: '解除屏蔽', en: 'Unblock')
                      : uiText(context, zh: '屏蔽对方', en: 'Block user'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  uiText(context, zh: '删除会话', en: 'Delete conversation'),
                  style: TextStyle(color: t.danger),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: ZxInlineMessage(
                message: _error!,
                tone: ZxMessageTone.danger,
                actionLabel: uiText(context, zh: '重试', en: 'Retry'),
                onAction: _loading ? null : _loadMessages,
              ),
            ),
          Expanded(child: _buildMessageList()),
          if (_conversation.blockedByMe || _conversation.blockedByPeer)
            _buildBlockedPanel()
          else
            _buildComposer(),
        ],
      ),
    );
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfilePage(userId: userId),
      ),
    );
  }

  Future<void> _showMessageMenu(
    DirectMessageItem message,
    Offset position,
  ) async {
    final ZxTokens t = ZxTokens.of(context);
    PopupMenuItem<_MessageAction> item(
      _MessageAction value,
      IconData icon,
      String label, {
      String? note,
    }) {
      return PopupMenuItem<_MessageAction>(
        value: value,
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: t.text2),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: ZxType.body.copyWith(color: t.text)),
            ),
            if (note != null) ...<Widget>[
              const SizedBox(width: 16),
              Text(note, style: ZxType.caption.copyWith(color: t.text3)),
            ],
          ],
        ),
      );
    }

    final _MessageAction? action = await showMenu<_MessageAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: <PopupMenuEntry<_MessageAction>>[
        item(
          _MessageAction.copy,
          Icons.copy_rounded,
          uiText(context, zh: '复制', en: 'Copy'),
        ),
        if (!_conversation.isBlocked)
          item(
            _MessageAction.reply,
            Icons.reply_rounded,
            uiText(context, zh: '回复', en: 'Reply'),
          ),
        if (message.fromMe && message.canRecall)
          item(
            _MessageAction.recall,
            Icons.undo_rounded,
            uiText(context, zh: '撤回', en: 'Recall'),
            note: uiText(context, zh: '2 分钟内', en: 'within 2 min'),
          ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.content));
        if (!mounted) return;
        zxShowToast(
          context,
          uiText(context, zh: '已复制到剪贴板', en: 'Copied to clipboard'),
        );
      case _MessageAction.reply:
        setState(() => _replyingTo = message);
        _inputFocusNode.requestFocus();
      case _MessageAction.recall:
        await _handleRecall(message);
    }
  }

  Widget _buildMessageList() {
    final ZxTokens t = ZxTokens.of(context);
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final bool hasFailed = _lastFailedContent != null;
    if (_messages.isEmpty && !hasFailed) {
      return ZxStatePanel(
        icon: Icons.waving_hand_outlined,
        title: _error == null
            ? uiText(context, zh: '还没有消息', en: 'No messages yet')
            : uiText(context, zh: '消息加载失败', en: 'Could not load messages'),
        message: _error == null
            ? uiText(context, zh: '先打个招呼吧', en: 'Say hello first.')
            : null,
      );
    }
    final List<Widget> rows = <Widget>[];
    DateTime? previous;
    for (final DirectMessageItem message in _messages) {
      final DateTime? at = DateTime.tryParse(message.createdAt)?.toLocal();
      if (at != null &&
          (previous == null || at.difference(previous) >= _separatorGap)) {
        rows.add(_TimeSeparator(label: _separatorLabel(at)));
      }
      if (at != null) previous = at;
      rows.add(
        _recalledIds.contains(message.id)
            ? _SystemLine(
                text: uiText(
                  context,
                  zh: '你撤回了一条消息',
                  en: 'You recalled a message',
                ),
              )
            : _buildBubble(message),
      );
    }
    if (hasFailed) rows.add(_buildFailedBubble(_lastFailedContent!));
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
        if (_messages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              uiText(context, zh: '还没有其他消息', en: 'No other messages'),
              textAlign: TextAlign.center,
              style: ZxType.caption.copyWith(color: t.text3),
            ),
          ),
      ],
    );
  }

  String _separatorLabel(DateTime at) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(at.year, at.month, at.day);
    String two(int v) => v.toString().padLeft(2, '0');
    final String hm = '${two(at.hour)}:${two(at.minute)}';
    final int days = today.difference(day).inDays;
    if (days == 0) return uiText(context, zh: '今天 $hm', en: 'Today $hm');
    if (days == 1) return uiText(context, zh: '昨天 $hm', en: 'Yesterday $hm');
    final String md = '${two(at.month)}-${two(at.day)}';
    return at.year == now.year ? '$md $hm' : '${at.year}-$md $hm';
  }

  Widget _buildBubble(DirectMessageItem message) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final bool mine = message.fromMe;
    final Color fg = mine ? t.onPrimary : t.text;
    final Color meta = mine ? t.onPrimary.withValues(alpha: 0.78) : t.text3;
    final String meta1 = mine
        ? '${message.timeText} · ${message.isRead ? uiText(context, zh: '已读', en: 'Read') : uiText(context, zh: '未读', en: 'Unread')}'
        : message.timeText;

    final Widget bubble = GestureDetector(
      onSecondaryTapDown: (TapDownDetails d) =>
          _showMessageMenu(message, d.globalPosition),
      onLongPressStart: (LongPressStartDetails d) =>
          _showMessageMenu(message, d.globalPosition),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? t.primary : t.surface,
          gradient: mine
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[t.primary, t.primaryPressed],
                )
              : null,
          border: mine ? null : Border.all(color: t.line),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 6),
            bottomRight: Radius.circular(mine ? 6 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (message.hasReply)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: mine ? t.onPrimary.withValues(alpha: 0.16) : t.bgSunk,
                  borderRadius: ZxRadius.badgeAll,
                ),
                child: Text(
                  uiText(
                    context,
                    zh: '回复 ${localizedAlias(locale, message.replyToSender ?? '匿名同学')}：${message.replyToContent}',
                    en: 'Reply to ${localizedAlias(locale, message.replyToSender ?? '匿名同学')}: ${message.replyToContent}',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZxType.caption.copyWith(
                    color: mine ? t.onPrimary.withValues(alpha: 0.88) : t.text2,
                  ),
                ),
              ),
            Text(message.content, style: ZxType.body.copyWith(color: fg)),
            const SizedBox(height: 4),
            Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              widthFactor: 1,
              child: Text(meta1, style: ZxType.micro.copyWith(color: meta)),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!mine) ...<Widget>[
            ZxAvatar(
              name: message.senderAliasFor(locale),
              imageUrl: _conversation.avatarUrl,
              size: 28,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _buildFailedBubble(String content) {
    final ZxTokens t = ZxTokens.of(context);
    return Padding(
      key: const Key('chat-failed-message'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          InkWell(
            borderRadius: ZxRadius.badgeAll,
            onTap: _sending
                ? null
                : () => _send(
                    retryContent: _lastFailedContent,
                    retryReplyTarget: _lastFailedReplyTarget,
                  ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.error_outline_rounded, size: 15, color: t.danger),
                  const SizedBox(width: 4),
                  Text(
                    uiText(context, zh: '发送失败 · 重发', en: 'Not sent · Retry'),
                    style: ZxType.caption.copyWith(
                      color: t.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Text(
                content,
                style: ZxType.body.copyWith(color: t.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final ZxTokens t = ZxTokens.of(context);
    final bool canSend = !_loading && !_sending;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_replyingTo != null) _buildReplyBanner(_replyingTo!),
                Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: ZxRadius.cardAll,
                    border: Border.all(color: t.line),
                    boxShadow: t.shadow1,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      EmojiAssistantBar(
                        controller: _inputController,
                        compact: true,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          key: const Key('chat-input'),
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          enabled: !_sending,
                          textInputAction: TextInputAction.send,
                          style: ZxType.body.copyWith(color: t.text),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            hintText: uiText(
                              context,
                              zh: '输入消息，回车发送',
                              en: 'Type a message, Enter to send',
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: _SendButton(
                          sending: _sending,
                          onPressed: canSend ? () => _send() : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBanner(DirectMessageItem message) {
    final ZxTokens t = ZxTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
      decoration: BoxDecoration(
        color: t.primarySoft,
        borderRadius: ZxRadius.badgeAll,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: t.primary,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(ZxRadius.badge),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  uiText(
                    context,
                    zh: '回复 ${_displaySender(message)} · ${message.content}',
                    en: 'Reply to ${_displaySender(message)} · ${message.content}',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZxType.caption.copyWith(fontSize: 13, color: t.text2),
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _replyingTo = null),
              icon: Icon(Icons.close_rounded, size: 16, color: t.text3),
              tooltip: uiText(context, zh: '取消回复', en: 'Cancel reply'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  /// H3: in place of the input. Only the side that blocked can undo it.
  Widget _buildBlockedPanel() {
    final ZxTokens t = ZxTokens.of(context);
    final bool byMe = _conversation.blockedByMe;
    return Container(
      key: const Key('chat-blocked-panel'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.block_rounded, size: 15, color: t.text2),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          byMe
                              ? uiText(
                                  context,
                                  zh: '你已屏蔽对方，不能收发消息',
                                  en: 'You blocked this user. Messages are off.',
                                )
                              : uiText(
                                  context,
                                  zh: '对方已屏蔽你，只能查看历史消息',
                                  en: 'This user blocked you. You can only read past messages.',
                                ),
                          textAlign: TextAlign.center,
                          style: ZxType.caption.copyWith(
                            fontSize: 13,
                            color: t.text2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (byMe) ...<Widget>[
                    const SizedBox(height: 12),
                    ZxButton(
                      key: const Key('chat-unblock'),
                      label: uiText(context, zh: '解除屏蔽', en: 'Unblock'),
                      variant: ZxButtonVariant.secondary,
                      expand: true,
                      onPressed: () => _toggleBlock(false),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRecall(DirectMessageItem message) async {
    if (!message.canRecall) {
      zxShowToast(
        context,
        uiText(
          context,
          zh: '只能撤回 2 分钟内自己发送的消息',
          en: 'You can only recall your own messages within 2 minutes.',
        ),
      );
      return;
    }
    final bool recalledLastMessage =
        _messages.isNotEmpty && _messages.last.id == message.id;
    try {
      await AppRepositories.messages.recallMessage(
        conversationId: widget.conversation.id,
        messageId: message.id,
      );
      if (!mounted) return;
      setState(() {
        _recalledIds.add(message.id);
        if (_replyingTo?.id == message.id) {
          _replyingTo = null;
        }
        if (_lastFailedReplyTarget?.id == message.id) {
          _lastFailedReplyTarget = null;
        }
      });
      if (recalledLastMessage) {
        widget.onMessageSent?.call(
          _conversationPreviewText(
            _messages
                .where((DirectMessageItem m) => !_recalledIds.contains(m.id))
                .toList(),
          ),
        );
      }
      zxShowToast(
        context,
        uiText(context, zh: '消息已撤回', en: 'Message recalled'),
      );
    } catch (error) {
      if (!mounted) return;
      zxShowToast(
        context,
        uiTextGlobal(zh: '撤回失败：$error', en: 'Recall failed: $error'),
      );
    }
  }

  String _displaySender(DirectMessageItem? message) {
    final Locale locale = appLocale;
    if (message == null) {
      return localizedAlias(locale, '匿名同学');
    }
    return message.fromMe
        ? uiTextFor(locale, zh: '我', en: 'Me')
        : message.senderAliasFor(locale);
  }

  String _conversationPreviewText(List<DirectMessageItem> messages) {
    if (messages.isEmpty) {
      return uiTextGlobal(zh: '开始聊天吧', en: 'Start the conversation');
    }
    return messages.last.content.trim().isEmpty
        ? uiTextGlobal(zh: '开始聊天吧', en: 'Start the conversation')
        : messages.last.content;
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<DirectMessageItem> messages = await AppRepositories.messages
          .fetchConversationMessages(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _recalledIds.clear();
        _conversation = _conversation.copyWith(
          unreadCount: 0,
          hasUnread: false,
        );
      });
      widget.onConversationRead?.call();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = uiTextGlobal(
          zh: '消息加载失败：$error',
          en: 'Could not load messages: $error',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _send({
    String? retryContent,
    DirectMessageItem? retryReplyTarget,
  }) async {
    final String content = (retryContent ?? _inputController.text).trim();
    final DirectMessageItem? replyTarget = retryReplyTarget ?? _replyingTo;
    if (content.isEmpty || _sending) return;
    setState(() {
      _sending = true;
    });
    try {
      final DirectMessageItem created = await AppRepositories.messages
          .sendConversationMessage(
            conversationId: widget.conversation.id,
            content: content,
            replyToId: replyTarget?.id,
          );
      final DirectMessageItem finalCreated = created.hasReply
          ? created
          : created.copyWith(
              replyToId: replyTarget?.id,
              replyToSender: _displaySender(replyTarget),
              replyToContent: replyTarget?.content,
            );
      if (!mounted) return;
      setState(() {
        _messages = <DirectMessageItem>[..._messages, finalCreated];
        _lastFailedContent = null;
        _lastFailedReplyTarget = null;
        _replyingTo = null;
        if (retryContent == null) _inputController.clear();
      });
      widget.onMessageSent?.call(finalCreated.content);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      // The failed text moves into a 发送失败 · 重发 bubble at the end.
      setState(() {
        _lastFailedContent = content;
        _lastFailedReplyTarget = replyTarget;
        if (retryContent == null) {
          _inputController.clear();
          _replyingTo = null;
        }
      });
      zxShowToast(
        context,
        uiTextGlobal(zh: '发送失败：$error', en: 'Send failed: $error'),
      );
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _toggleBlock(bool block) async {
    if (block) {
      final bool confirmed = await zxConfirm(
        context,
        title: uiText(context, zh: '屏蔽对方？', en: 'Block this user?'),
        message: uiText(
          context,
          zh: '屏蔽后双方都不能再发消息，历史消息保留。可以随时解除。',
          en:
              'Neither of you can send messages; history is kept. You can '
              'unblock at any time.',
        ),
        confirmLabel: uiText(context, zh: '屏蔽', en: 'Block'),
        cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
        danger: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _error = null;
    });
    try {
      final ConversationItem updated = await AppRepositories.messages
          .updateConversationBlock(
            conversationId: _conversation.id,
            block: block,
          );
      if (!mounted) return;
      setState(() {
        _conversation = _conversation.copyWith(
          blockedByMe: updated.blockedByMe,
          blockedByPeer: updated.blockedByPeer,
        );
        if (_conversation.isBlocked) _replyingTo = null;
      });
      widget.onConversationFlagsChanged?.call(
        blockedByMe: updated.blockedByMe,
        blockedByPeer: updated.blockedByPeer,
      );
      zxShowToast(
        context,
        block
            ? uiText(context, zh: '已屏蔽对方', en: 'User blocked')
            : uiText(context, zh: '已解除屏蔽', en: 'User unblocked'),
      );
    } catch (error) {
      if (!mounted) return;
      zxShowToast(
        context,
        uiTextGlobal(zh: '操作失败：$error', en: 'Action failed: $error'),
      );
    }
  }

  Future<void> _deleteConversation() async {
    final bool confirmed = await zxConfirm(
      context,
      title: uiText(context, zh: '删除会话', en: 'Delete conversation'),
      message: uiText(
        context,
        zh: '删除后仅从你的列表中移除，会话历史不会立即物理删除。',
        en: 'This only removes the conversation from your list; the history is not deleted immediately.',
      ),
      confirmLabel: uiText(context, zh: '删除', en: 'Delete'),
      cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await AppRepositories.messages.deleteConversation(_conversation.id);
      if (!mounted) return;
      widget.onConversationRemoved?.call();
      zxShowToast(
        context,
        uiText(context, zh: '会话已删除', en: 'Conversation deleted'),
      );
      if (!widget.embedded) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      zxShowToast(
        context,
        uiTextGlobal(
          zh: '删除会话失败：$error',
          en: 'Could not delete the conversation: $error',
        ),
      );
    }
  }
}

class _TimeSeparator extends StatelessWidget {
  const _TimeSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: t.bgSunk,
            borderRadius: ZxRadius.badgeAll,
          ),
          child: Text(label, style: ZxType.caption.copyWith(color: t.text3)),
        ),
      ),
    );
  }
}

class _SystemLine extends StatelessWidget {
  const _SystemLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: ZxType.caption.copyWith(color: ZxTokens.of(context).text3),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onPressed});

  final bool sending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Tooltip(
      message: uiText(context, zh: '发送', en: 'Send'),
      child: Material(
        color: onPressed == null ? t.primary.withValues(alpha: 0.5) : t.primary,
        borderRadius: ZxRadius.buttonAll,
        child: InkWell(
          key: const Key('chat-send'),
          borderRadius: ZxRadius.buttonAll,
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: sending
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.onPrimary,
                      ),
                    )
                  : Icon(Icons.send_rounded, size: 18, color: t.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
