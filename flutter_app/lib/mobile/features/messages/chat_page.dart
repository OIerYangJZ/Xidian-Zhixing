import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/design_system.dart';
import '../../../core/network/api_exception.dart';
import '../../core/state/mobile_providers.dart';
import '../widgets/avatar_widget.dart';
import 'package:xdu_treehole_web/models/direct_message_item.dart';

/// 聊天 (handoff H1–H4). Bubbles carry their time and read state; a failed
/// send stays in place with a red retry button. Long-press dims the page
/// and opens the action grid (回复 复制 详情 / 撤回 转发 多选); 多选 turns the
/// bars into 取消 · 已选择 N 条 · 全选 over 逐条转发 and 撤回 N 条. Blocking
/// replaces the input with a note (and 解除屏蔽 when it is ours).
class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  final String? peerName;
  final String? peerAvatar;
  final String? peerUserId;

  const ChatPage({
    super.key,
    required this.conversationId,
    this.peerName,
    this.peerAvatar,
    this.peerUserId,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  List<DirectMessageItem> _messages = [];
  bool _isLoading = true;
  String? _error;
  bool _isSending = false;

  /// The peer has written in this chat (even a message since recalled).
  /// Until then, one first message is all I can send.
  bool _openedByPeer = false;

  /// The server refused a send with 对方回复前只能发送一条消息.
  bool _serverSaysWait = false;
  bool _blockedByMe = false;
  bool _blockedByPeer = false;
  bool _unblocking = false;
  bool _selectMode = false;
  final Set<String> _selectedMessages = {};
  OverlayEntry? _overlayEntry;

  /// 当前正在回复的消息
  DirectMessageItem? _replyingTo;

  /// Handoff H4: my first message is out and the peer has not replied.
  bool get _awaitingReply {
    if (_openedByPeer || _messages.any((m) => !m.fromMe)) return false;
    return _serverSaysWait ||
        _messages.any(
          (m) =>
              m.fromMe &&
              !_isRecalled(m) &&
              m.deliveryStatus != 'failed' &&
              m.deliveryStatus != 'sending',
        );
  }

  String get _peerName =>
      (widget.peerName ?? '').trim().isEmpty ? '用户' : widget.peerName!.trim();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _hideOverlay(rebuild: false);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final messages = await messageRepo.fetchConversationMessages(
        widget.conversationId,
      );
      // 后端已在获取消息时自动标记已读，这里同步更新本地状态
      ref
          .read(messagesControllerProvider.notifier)
          .markConversationRead(widget.conversationId);

      // 查找会话的屏蔽状态
      final conversation = ref
          .read(messagesControllerProvider)
          .conversations
          .where((c) => c.id == widget.conversationId)
          .firstOrNull;

      if (mounted) {
        setState(() {
          _messages = messages;
          _blockedByMe = conversation?.blockedByMe ?? false;
          _blockedByPeer = conversation?.blockedByPeer ?? false;
          // The server counts recalled replies too; it knows best when it
          // says the chat is open although only my messages are visible.
          _openedByPeer =
              messages.any((m) => !m.fromMe) ||
              (conversation != null &&
                  !conversation.awaitingReply &&
                  messages.isNotEmpty);
          _serverSaysWait = conversation?.awaitingReply ?? false;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSend() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    final replyTarget = _replyingTo;

    // 清空输入框和回复状态
    _messageController.clear();
    setState(() => _replyingTo = null);

    // 乐观更新：先添加消息到列表
    final tempMessage = DirectMessageItem(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      createdAt: DateTime.now().toIso8601String(),
      timeText: '刚刚',
      fromMe: true,
      senderAlias: '我',
      isRead: false,
      readAt: '',
      deliveryStatus: 'sending',
      serverCanRecall: true,
      replyToId: replyTarget?.id,
      replyToSender: replyTarget?.senderAlias,
      replyToContent: replyTarget?.content,
    );

    setState(() {
      _messages.add(tempMessage);
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final sentMessage = await ref
          .read(messageRepositoryProvider)
          .sendConversationMessage(
            conversationId: widget.conversationId,
            content: content,
            replyToId: replyTarget?.id,
          );

      // 后端若不支持回复字段，用乐观数据补充
      final finalMessage = sentMessage.hasReply
          ? sentMessage
          : sentMessage.copyWith(
              replyToId: replyTarget?.id,
              replyToSender: replyTarget?.senderAlias,
              replyToContent: replyTarget?.content,
            );

      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempMessage.id);
          if (index != -1) _messages[index] = finalMessage;
        });
        // 更新上层会话列表的预览和未读数
        final notifier = ref.read(messagesControllerProvider.notifier);
        notifier.updateConversationPreview(
          conversationId: widget.conversationId,
          message: content,
        );
        notifier.updateConversationFlags(
          conversationId: widget.conversationId,
          awaitingReply: _awaitingReply,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403 && e.message.contains('对方回复前')) {
        // Nothing was sent: drop the bubble and show the wait instead.
        setState(() {
          _messages.removeWhere((m) => m.id == tempMessage.id);
          _serverSaysWait = true;
        });
        _messageController.text = content;
        zxShowToast(context, e.message);
      } else {
        _markFailed(tempMessage);
        debugPrint('私信发送失败: ${e.message}');
      }
    } catch (e) {
      // 发送失败：留在原位，点左侧按钮重发
      if (mounted) {
        _markFailed(tempMessage);
        debugPrint('私信发送失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _markFailed(DirectMessageItem temp) {
    setState(() {
      final index = _messages.indexWhere((m) => m.id == temp.id);
      if (index != -1) {
        _messages[index] = temp.copyWith(
          timeText: '发送失败',
          deliveryStatus: 'failed',
          serverCanRecall: false,
        );
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---- layout ----

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return PopScope(
      canPop: _overlayEntry == null && !_selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_overlayEntry != null) {
          _hideOverlay();
        } else if (_selectMode) {
          _exitSelectMode();
        }
      },
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: _selectMode ? _buildSelectAppBar(t) : _buildAppBar(t),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ZxStatePanel(
                      error: true,
                      icon: Icons.error_outline_rounded,
                      title: '消息加载失败',
                      message: _error,
                      actionLabel: '重试',
                      onAction: _loadMessages,
                    )
                  : _buildMessageList(t),
            ),
            if (_selectMode)
              _buildSelectBar(t)
            else if (_blockedByMe || _blockedByPeer)
              _buildBlockedBar(t)
            else if (_awaitingReply)
              _buildWaitingBar(t)
            else
              _buildInputArea(t),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ZxTokens t) {
    final VoidCallback? openPeer = widget.peerUserId != null
        ? () => context.push('/user/${widget.peerUserId}')
        : null;
    return AppBar(
      backgroundColor: t.surface,
      titleSpacing: 0,
      leading: IconButton(
        tooltip: '返回',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.pop(),
      ),
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: openPeer,
        child: Row(
          children: [
            AvatarWidget(
              avatarUrl: widget.peerAvatar,
              nickname: _peerName,
              radius: 19,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _peerName,
                          overflow: TextOverflow.ellipsis,
                          style: ZxType.label.copyWith(
                            fontSize: 16,
                            color: t.text,
                          ),
                        ),
                      ),
                      if (_blockedByMe) ...[
                        const SizedBox(width: 6),
                        const ZxBadge.blocked('已屏蔽'),
                      ],
                    ],
                  ),
                  if (openPeer != null)
                    Text(
                      '查看主页',
                      style: ZxType.micro.copyWith(
                        color: t.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          key: const Key('mobile-chat-more'),
          tooltip: '更多',
          icon: const Icon(Icons.more_horiz),
          onPressed: _showOptionsSheet,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectAppBar(ZxTokens t) {
    final bool all =
        _selectableIds.isNotEmpty &&
        _selectedMessages.length == _selectableIds.length;
    return AppBar(
      backgroundColor: t.surface,
      automaticallyImplyLeading: false,
      leadingWidth: 72,
      leading: TextButton(
        onPressed: _exitSelectMode,
        style: TextButton.styleFrom(foregroundColor: t.text),
        child: const Text('取消'),
      ),
      centerTitle: true,
      title: Text('已选择 ${_selectedMessages.length} 条'),
      actions: [
        TextButton(
          key: const Key('mobile-chat-select-all'),
          onPressed: () => setState(() {
            if (all) {
              _selectedMessages.clear();
            } else {
              _selectedMessages
                ..clear()
                ..addAll(_selectableIds);
            }
          }),
          style: TextButton.styleFrom(foregroundColor: t.primary),
          child: Text(all ? '全不选' : '全选'),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// Everything but recalled placeholders can be picked.
  List<String> get _selectableIds => _messages
      .where((m) => !_isRecalled(m) && m.deliveryStatus != 'failed')
      .map((m) => m.id)
      .toList();

  Widget _buildMessageList(ZxTokens t) {
    final List<Object> rows = _groupMessagesByTime();

    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
        _hideOverlay();
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          if (!_openedByPeer && !_messages.any((m) => !m.fromMe))
            _buildFirstMessageNote(t),
          for (final Object row in rows)
            if (row is String)
              _buildTimeLabel(t, row)
            else if (row is DirectMessageItem)
              _buildMessageRow(t, row),
        ],
      ),
    );
  }

  /// Handoff H4. Before the peer has written: the first message goes
  /// straight to them, and it is the only one until they reply.
  Widget _buildFirstMessageNote(ZxTokens t) {
    final bool waiting = _awaitingReply;
    return Container(
      key: const Key('mobile-chat-first-message-note'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: ZxRadius.cardAll,
        border: Border.all(color: t.line),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: t.heroGradient,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: ZxRadius.buttonAll,
            ),
            child: Icon(
              waiting ? Icons.mark_email_read_outlined : Icons.mail_outline,
              size: 20,
              color: t.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            waiting ? '消息已发送' : '和 $_peerName 打个招呼',
            style: ZxType.label.copyWith(fontSize: 15, color: t.text),
          ),
          const SizedBox(height: 4),
          Text(
            waiting
                ? '$_peerName 回复之前，你只能发送 1 条消息'
                : '第一条消息会直接发给对方；对方回复之前只能发这一条，请说清来意',
            textAlign: TextAlign.center,
            style: ZxType.caption.copyWith(color: t.text2, height: 1.5),
          ),
        ],
      ),
    );
  }

  /// The input, locked while the first message waits for a reply.
  Widget _buildWaitingBar(ZxTokens t) {
    return Container(
      key: const Key('mobile-chat-waiting'),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: t.warning),
                const SizedBox(width: 6),
                Text(
                  '等待对方回复后可继续发送',
                  style: ZxType.caption.copyWith(
                    color: t.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 44,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: t.bgSunk,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                '暂时不能发送',
                style: ZxType.body.copyWith(color: t.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Object> _groupMessagesByTime() {
    final List<Object> result = [];
    DateTime? lastTime;
    for (final message in _messages) {
      // 解析 UTC 时间并转换为本地时区，避免时区偏差
      final messageTime = _localTime(message.createdAt);
      if (lastTime == null || messageTime.difference(lastTime).inMinutes > 5) {
        result.add(_formatTimeLabel(messageTime));
        lastTime = messageTime;
      }
      result.add(message);
    }
    return result;
  }

  DateTime _localTime(String createdAt) =>
      DateTime.tryParse(createdAt)?.toUtc().toLocal() ?? DateTime.now();

  String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _formatTimeLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);
    if (messageDay == today) return '今天 ${_clock(time)}';
    if (messageDay == today.subtract(const Duration(days: 1))) {
      return '昨天 ${_clock(time)}';
    }
    return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${_clock(time)}';
  }

  Widget _buildTimeLabel(ZxTokens t, String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: t.bgSunk,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: ZxType.micro.copyWith(color: t.text3)),
      ),
    );
  }

  bool _isRecalled(DirectMessageItem message) =>
      message.deliveryStatus == 'recalled';

  DirectMessageItem _toRecalledMessage(DirectMessageItem message) {
    return message.copyWith(
      content: message.fromMe ? '你撤回了一条消息' : '对方撤回了一条消息',
      deliveryStatus: 'recalled',
      serverCanRecall: false,
    );
  }

  String _conversationPreviewText(List<DirectMessageItem> messages) {
    if (messages.isEmpty) return '开始聊天吧';
    final String content = messages.last.content.trim();
    return content.isEmpty ? '开始聊天吧' : content;
  }

  Widget _buildMessageRow(ZxTokens t, DirectMessageItem message) {
    if (_isRecalled(message)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            message.content,
            style: ZxType.caption.copyWith(color: t.text3),
          ),
        ),
      );
    }

    final bool isMe = message.fromMe;
    final bool failed = message.deliveryStatus == 'failed';
    final bool selected = _selectedMessages.contains(message.id);
    // In 多选, what cannot be recalled is greyed but still pickable.
    final bool faded = _selectMode && !message.canRecall;
    final bool selectable = _selectableIds.contains(message.id);

    final Widget bubble = GestureDetector(
      key: Key('mobile-chat-message-${message.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: _selectMode && selectable ? () => _toggleSelect(message) : null,
      onLongPressStart: _selectMode || failed
          ? null
          : (details) => _showMessageMenu(message, details.globalPosition),
      child: _Bubble(message: message, time: _bubbleTime(message)),
    );

    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_selectMode) ...[
            _SelectDot(selected: selected, enabled: selectable),
            const SizedBox(width: 10),
          ],
          if (_selectMode && isMe) const Spacer(),
          if (!isMe) ...[
            GestureDetector(
              onTap: widget.peerUserId != null && !_selectMode
                  ? () => context.push('/user/${widget.peerUserId}')
                  : null,
              child: AvatarWidget(
                avatarUrl: widget.peerAvatar,
                nickname: _peerName,
                radius: 15,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (failed) ...[
            IconButton.filled(
              key: Key('mobile-chat-retry-${message.id}'),
              tooltip: '重发',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: t.danger,
                foregroundColor: t.onDanger,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: () => _retrySend(message),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: Opacity(
                opacity: failed || faded ? 0.55 : 1,
                child: bubble,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (_selectMode && selected)
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.primarySoft,
              borderRadius: ZxRadius.buttonAll,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: row,
            ),
          )
        else
          row,
        if (failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '发送失败，点左侧按钮重发',
              style: ZxType.micro.copyWith(
                color: t.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  String _bubbleTime(DirectMessageItem message) {
    final String clock = _clock(_localTime(message.createdAt));
    if (!message.fromMe) return clock;
    return switch (message.deliveryStatus) {
      'sending' => '$clock · 发送中',
      'failed' => clock,
      _ => '$clock · ${message.isRead ? '已读' : '未读'}',
    };
  }

  // ---- long-press menu (H1) ----

  void _showMessageMenu(DirectMessageItem message, Offset at) {
    _hideOverlay(rebuild: false);
    _focusNode.unfocus();
    HapticFeedback.mediumImpact();
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    const double menuWidth = 280;
    const double menuHeight = 190;
    final double left = message.fromMe ? screen.width - menuWidth - 20 : 20.0;
    // Below the finger when there is room, otherwise above it.
    final bool below = at.dy + 16 + menuHeight < screen.height - padding.bottom;
    final double top = below
        ? at.dy + 16
        : (at.dy - menuHeight - 16).clamp(padding.top + 8, screen.height);

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideOverlay,
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(color: ZxTokens.of(ctx).scrim),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: _MessageMenu(
              message: message,
              onReply: () => _handleReply(message),
              onCopy: () {
                Clipboard.setData(ClipboardData(text: message.content));
                _hideOverlay();
                zxShowToast(context, '已复制');
              },
              onDetail: () => _showMessageDetail(message),
              onRecall: () => _handleRecall(message),
              onForward: () => _openForwardPicker(<DirectMessageItem>[message]),
              onSelect: () {
                _hideOverlay();
                setState(() {
                  _selectMode = true;
                  _selectedMessages
                    ..clear()
                    ..add(message.id);
                });
              },
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    if (mounted) setState(() {});
  }

  void _hideOverlay({bool rebuild = true}) {
    if (_overlayEntry == null) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (rebuild && mounted) setState(() {});
  }

  // ---- 多选 (H2) ----

  void _toggleSelect(DirectMessageItem message) {
    setState(() {
      if (!_selectedMessages.remove(message.id)) {
        _selectedMessages.add(message.id);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedMessages.clear();
    });
  }

  List<DirectMessageItem> get _selected =>
      _messages.where((m) => _selectedMessages.contains(m.id)).toList();

  Widget _buildSelectBar(ZxTokens t) {
    final int recallable = _selected.where((m) => m.canRecall).length;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '只能撤回自己 2 分钟内发送的消息，其余已置灰',
              style: ZxType.caption.copyWith(color: t.text3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ZxButton(
                    key: const Key('mobile-chat-forward-selected'),
                    label: '逐条转发',
                    icon: Icons.redo_rounded,
                    variant: ZxButtonVariant.secondary,
                    expand: true,
                    onPressed: _selectedMessages.isEmpty
                        ? null
                        : () => _openForwardPicker(_selected),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ZxButton(
                    key: const Key('mobile-chat-recall-selected'),
                    label: recallable > 0 ? '撤回 $recallable 条' : '撤回',
                    icon: Icons.undo_rounded,
                    expand: true,
                    onPressed: recallable == 0 ? null : _batchRecall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _batchRecall() async {
    final Set<String> recallableIds = _selected
        .where((m) => m.canRecall)
        .map((m) => m.id)
        .toSet();
    if (recallableIds.isEmpty) return;
    final bool confirmed = await zxConfirm(
      context,
      title: '撤回 ${recallableIds.length} 条消息？',
      message: '撤回后对方将看不到这些消息。',
      confirmLabel: '撤回',
      cancelLabel: '取消',
      danger: true,
    );
    if (!confirmed || !mounted) return;

    final repo = ref.read(messageRepositoryProvider);
    final Set<String> done = <String>{};
    try {
      for (final String id in recallableIds) {
        await repo.recallMessage(
          conversationId: widget.conversationId,
          messageId: id,
        );
        done.add(id);
      }
    } catch (e) {
      if (mounted) zxShowToast(context, '撤回失败：$e');
    }
    if (!mounted) return;
    setState(() {
      _messages = _messages
          .map((m) => done.contains(m.id) ? _toRecalledMessage(m) : m)
          .toList();
      _selectedMessages.clear();
      _selectMode = false;
      if (_replyingTo != null && done.contains(_replyingTo!.id)) {
        _replyingTo = null;
      }
    });
    ref
        .read(messagesControllerProvider.notifier)
        .updateConversationPreview(
          conversationId: widget.conversationId,
          message: _conversationPreviewText(_messages),
        );
    if (done.isNotEmpty) zxShowToast(context, '已撤回 ${done.length} 条消息');
  }

  Future<void> _handleRecall(DirectMessageItem message) async {
    _hideOverlay();
    if (!message.canRecall) {
      zxShowToast(context, '只能撤回 2 分钟内自己发送的消息');
      return;
    }
    final recalledLastMessage =
        _messages.isNotEmpty && _messages.last.id == message.id;
    try {
      await ref
          .read(messageRepositoryProvider)
          .recallMessage(
            conversationId: widget.conversationId,
            messageId: message.id,
          );
      if (!mounted) return;
      setState(() {
        final int index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1)
          _messages[index] = _toRecalledMessage(_messages[index]);
        _selectedMessages.remove(message.id);
        if (_replyingTo?.id == message.id) _replyingTo = null;
      });
      if (recalledLastMessage) {
        ref
            .read(messagesControllerProvider.notifier)
            .updateConversationPreview(
              conversationId: widget.conversationId,
              message: _conversationPreviewText(_messages),
            );
      }
      zxShowToast(context, '消息已撤回');
    } catch (e) {
      if (mounted) zxShowToast(context, '撤回失败：$e');
    }
  }

  String _formatFullTime(String createdAt) {
    final dt = _localTime(createdAt);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${_clock(dt)}:${dt.second.toString().padLeft(2, '0')}';
  }

  void _showMessageDetail(DirectMessageItem message) {
    _hideOverlay();
    final ZxTokens t = ZxTokens.of(context);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: ZxType.caption.copyWith(color: t.text3)),
          ),
          Expanded(
            child: Text(value, style: ZxType.caption.copyWith(color: t.text)),
          ),
        ],
      ),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('消息详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('发送时间', _formatFullTime(message.createdAt)),
            row('发送方', message.fromMe ? '我' : message.senderAlias),
            if (message.fromMe)
              row(
                '状态',
                message.deliveryStatus == 'failed'
                    ? '发送失败'
                    : message.isRead
                    ? '已读'
                    : '未读',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 转发 one message, or 逐条转发 several in order, to another chat.
  void _openForwardPicker(List<DirectMessageItem> messages) {
    _hideOverlay();
    final available = ref
        .read(messagesControllerProvider)
        .conversations
        .where((c) => !c.isBlocked && c.id != widget.conversationId)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                messages.length > 1 ? '逐条转发 ${messages.length} 条给' : '转发给',
                style: ZxType.title,
              ),
            ),
            if (available.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '暂无其他会话',
                  textAlign: TextAlign.center,
                  style: ZxType.body.copyWith(color: ZxTokens.of(ctx).text3),
                ),
              )
            else
              for (final c in available)
                ListTile(
                  leading: AvatarWidget(
                    avatarUrl: c.avatarUrl,
                    nickname: c.name,
                    radius: 18,
                  ),
                  title: Text(c.name),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      for (final DirectMessageItem m in messages) {
                        await ref
                            .read(messageRepositoryProvider)
                            .sendConversationMessage(
                              conversationId: c.id,
                              content: '[转发] ${m.content}',
                            );
                      }
                      if (!mounted) return;
                      if (_selectMode) _exitSelectMode();
                      zxShowToast(context, '已转发');
                    } catch (e) {
                      if (mounted) zxShowToast(context, '转发失败：$e');
                    }
                  },
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _handleReply(DirectMessageItem message) {
    _hideOverlay();
    setState(() => _replyingTo = message);
    _focusNode.requestFocus();
  }

  void _retrySend(DirectMessageItem failedMessage) {
    setState(() {
      _messages.removeWhere((m) => m.id == failedMessage.id);
      if (failedMessage.hasReply) {
        _replyingTo = _messages
            .where((m) => m.id == failedMessage.replyToId)
            .firstOrNull;
      }
    });
    _messageController.text = failedMessage.content;
    _handleSend();
  }

  // ---- bottom bars ----

  Widget _buildInputArea(ZxTokens t) {
    final bool canSend =
        _messageController.text.trim().isNotEmpty && !_isSending;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null) _buildReplyPreviewBar(t),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 120,
                        minHeight: 44,
                      ),
                      decoration: BoxDecoration(
                        color: t.bgSunk,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        key: const Key('mobile-chat-input'),
                        controller: _messageController,
                        focusNode: _focusNode,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        style: ZxType.body.copyWith(color: t.text),
                        decoration: InputDecoration(
                          filled: false,
                          isDense: true,
                          hintText: '输入消息',
                          hintStyle: ZxType.body.copyWith(color: t.text3),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('mobile-chat-send'),
                    tooltip: '发送',
                    style: IconButton.styleFrom(
                      backgroundColor: t.primary,
                      foregroundColor: t.onPrimary,
                      disabledBackgroundColor: t.bgSunk,
                      disabledForegroundColor: t.text3,
                      fixedSize: const Size(44, 44),
                    ),
                    onPressed: canSend ? _handleSend : null,
                    icon: _isSending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.text3,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, size: 22),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 回复 name: text, over the input.
  Widget _buildReplyPreviewBar(ZxTokens t) {
    final msg = _replyingTo!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: t.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '回复 ${msg.fromMe ? '我' : msg.senderAlias}',
                  style: ZxType.micro.copyWith(
                    color: t.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  msg.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZxType.caption.copyWith(color: t.text2),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '取消回复',
            icon: Icon(Icons.close_rounded, size: 18, color: t.text3),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  /// Handoff H3: blocked chats keep their history but cannot send.
  Widget _buildBlockedBar(ZxTokens t) {
    return Container(
      key: const Key('mobile-chat-blocked'),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.line)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block_rounded, size: 16, color: t.danger),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _blockedByMe ? '你已屏蔽对方，不能收发消息' : '对方已屏蔽你，只能查看历史消息',
                    style: ZxType.caption.copyWith(
                      fontSize: 13,
                      color: t.text2,
                    ),
                  ),
                ),
              ],
            ),
            if (_blockedByMe) ...[
              const SizedBox(height: 12),
              ZxButton(
                key: const Key('mobile-chat-unblock'),
                label: '解除屏蔽',
                variant: ZxButtonVariant.secondary,
                expand: true,
                loading: _unblocking,
                onPressed: () => _setBlocked(false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---- options ----

  Future<void> _showOptionsSheet() async {
    final String? action = await zxShowActionSheet<String>(
      context,
      cancelLabel: '取消',
      actions: [
        if (widget.peerUserId != null)
          const ZxSheetAction<String>(
            value: 'profile',
            label: '查看对方主页',
            icon: Icons.person_outline_rounded,
          ),
        ZxSheetAction<String>(
          value: 'block',
          label: _blockedByMe ? '解除屏蔽' : '屏蔽对方',
          icon: Icons.block_rounded,
          danger: !_blockedByMe,
        ),
        const ZxSheetAction<String>(
          value: 'delete',
          label: '删除会话',
          icon: Icons.delete_outline_rounded,
          danger: true,
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'profile':
        context.push('/user/${widget.peerUserId}');
      case 'block':
        await _confirmBlock();
      case 'delete':
        await _confirmDeleteConversation();
    }
  }

  Future<void> _confirmDeleteConversation() async {
    final bool confirmed = await zxConfirm(
      context,
      title: '删除会话',
      message: '确定要删除这个会话吗？删除后双方聊天记录都将消失。',
      confirmLabel: '删除',
      cancelLabel: '取消',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      ref
          .read(messagesControllerProvider.notifier)
          .deleteConversation(widget.conversationId);
      context.pop();
      zxShowToast(context, '会话已删除');
    } catch (e) {
      zxShowToast(context, '删除失败：$e');
    }
  }

  Future<void> _confirmBlock() async {
    final bool blocking = !_blockedByMe;
    if (blocking) {
      final bool confirmed = await zxConfirm(
        context,
        title: '屏蔽对方',
        message: '屏蔽后双方都不能再发消息，聊天记录会保留。',
        confirmLabel: '屏蔽',
        cancelLabel: '取消',
        danger: true,
      );
      if (!confirmed || !mounted) return;
    }
    await _setBlocked(blocking);
  }

  Future<void> _setBlocked(bool block) async {
    setState(() => _unblocking = true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .updateConversationBlock(
            conversationId: widget.conversationId,
            block: block,
          );
      if (!mounted) return;
      setState(() => _blockedByMe = block);
      ref
          .read(messagesControllerProvider.notifier)
          .updateConversationFlags(
            conversationId: widget.conversationId,
            blockedByMe: block,
          );
      zxShowToast(context, block ? '已屏蔽对方' : '已解除屏蔽');
    } catch (e) {
      if (mounted) zxShowToast(context, '操作失败：$e');
    } finally {
      if (mounted) setState(() => _unblocking = false);
    }
  }
}

/// A message bubble: primary for mine, surface for theirs, with the quote
/// on top and the time (· 已读 / 未读) inside at the end.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.time});

  final DirectMessageItem message;
  final String time;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final bool isMe = message.fromMe;
    final Color fg = isMe ? t.onPrimary : t.text;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: isMe ? null : t.surface,
        gradient: isMe
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color.lerp(t.primary, t.surface, 0.08)!,
                  t.primaryPressed,
                ],
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 6),
          bottomRight: Radius.circular(isMe ? 6 : 18),
        ),
        border: isMe ? null : Border.all(color: t.line),
        boxShadow: isMe
            ? <BoxShadow>[
                BoxShadow(
                  color: t.primaryGlow,
                  blurRadius: 14,
                  spreadRadius: -6,
                  offset: const Offset(0, 6),
                ),
              ]
            : t.shadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.hasReply)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withValues(alpha: 0.16) : t.bgSunk,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '回复 ${message.replyToSender ?? ''}：${message.replyToContent ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ZxType.caption.copyWith(
                  color: isMe ? t.onPrimary.withValues(alpha: 0.85) : t.text2,
                ),
              ),
            ),
          Text(
            message.content,
            style: ZxType.body.copyWith(color: fg, height: 1.5),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            child: Text(
              time,
              style: ZxType.micro.copyWith(
                color: isMe ? t.onPrimary.withValues(alpha: 0.75) : t.text3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? t.primary : null,
        border: Border.all(
          color: selected
              ? t.primary
              : enabled
              ? t.lineStrong
              : t.line,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 14, color: t.onPrimary)
          : null,
    );
  }
}

/// The long-press grid of handoff H1. 撤回 shows only on my messages, and
/// greys out once the 2 minutes are up.
class _MessageMenu extends StatelessWidget {
  const _MessageMenu({
    required this.message,
    required this.onReply,
    required this.onCopy,
    required this.onDetail,
    required this.onRecall,
    required this.onForward,
    required this.onSelect,
  });

  final DirectMessageItem message;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onDetail;
  final VoidCallback onRecall;
  final VoidCallback onForward;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    Widget item(
      String key,
      IconData icon,
      String label,
      VoidCallback? onTap, {
      String? note,
    }) {
      final Color color = onTap == null ? t.text3 : t.text;
      return InkWell(
        key: Key('mobile-chat-menu-$key'),
        borderRadius: ZxRadius.buttonAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(label, style: ZxType.caption.copyWith(color: color)),
              if (note != null)
                Text(note, style: ZxType.micro.copyWith(color: t.text3)),
            ],
          ),
        ),
      );
    }

    final List<Widget> items = <Widget>[
      item('reply', Icons.reply_rounded, '回复', onReply),
      item('copy', Icons.copy_rounded, '复制', onCopy),
      item('detail', Icons.info_outline_rounded, '详情', onDetail),
      if (message.fromMe)
        item(
          'recall',
          Icons.undo_rounded,
          '撤回',
          message.canRecall ? onRecall : null,
          note: message.canRecall ? '2 分钟内' : '已超时',
        ),
      item('forward', Icons.redo_rounded, '转发', onForward),
      item('select', Icons.check_box_outlined, '多选', onSelect),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: ZxRadius.cardAll,
        border: Border.all(color: t.line),
        boxShadow: t.shadow2,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int row = 0; row * 3 < items.length; row++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = row * 3; i < row * 3 + 3; i++)
                      Expanded(
                        child: i < items.length ? items[i] : const SizedBox(),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
