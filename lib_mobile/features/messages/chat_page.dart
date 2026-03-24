import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';
import 'package:xdu_treehole_web/models/direct_message_item.dart';

/// 聊天页
/// 支持消息气泡、时间戳分组、表情栏、发送消息
class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  final String? peerName;
  final String? peerAvatar;

  const ChatPage({
    super.key,
    required this.conversationId,
    this.peerName,
    this.peerAvatar,
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
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
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
      final messages =
          await messageRepo.fetchConversationMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = messages;
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

    // 清空输入框
    _messageController.clear();

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
    );

    setState(() {
      _messages.add(tempMessage);
      _showEmoji = false;
    });
    _scrollToBottom();

    setState(() {
      _isSending = true;
    });

    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final sentMessage = await messageRepo.sendConversationMessage(
        conversationId: widget.conversationId,
        content: content,
      );

      // 更新消息状态为已发送
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = sentMessage;
          }
        });
      }
    } catch (e) {
      // 发送失败，标记为失败状态
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = DirectMessageItem(
              id: tempMessage.id,
              content: content,
              createdAt: tempMessage.createdAt,
              timeText: '发送失败',
              fromMe: true,
              senderAlias: '我',
              isRead: false,
              readAt: '',
              deliveryStatus: 'failed',
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
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

  void _toggleEmoji() {
    setState(() {
      _showEmoji = !_showEmoji;
    });
    if (_showEmoji) {
      _focusNode.unfocus();
    }
  }

  void _onTapEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji,
    );
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MobileTheme.background,
      appBar: AppBar(
        backgroundColor: MobileTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            // 头像
            if (widget.peerAvatar != null && widget.peerAvatar!.isNotEmpty)
              CircleAvatar(
                radius: 18,
                backgroundColor: MobileTheme.primary.withValues(alpha: 0.1),
                backgroundImage: NetworkImage(widget.peerAvatar!),
              )
            else
              CircleAvatar(
                radius: 18,
                backgroundColor: MobileTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  (widget.peerName ?? '用户').substring(0, 1),
                  style: const TextStyle(
                    color: MobileTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerName ?? '聊天',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showOptionsSheet(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : _buildMessageList(),
          ),

          // 输入区域
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: MobileTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: MobileTheme.textSecondary,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadMessages,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          '暂无消息，开始聊天吧~',
          style: TextStyle(
            color: MobileTheme.textTertiary,
            fontSize: 14,
          ),
        ),
      );
    }

    // 按时间分组消息
    final groupedMessages = _groupMessagesByTime();

    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
        setState(() {
          _showEmoji = false;
        });
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: groupedMessages.length,
        itemBuilder: (context, index) {
          final item = groupedMessages[index];
          if (item is String) {
            // 时间标签
            return _buildTimeLabel(item);
          } else if (item is DirectMessageItem) {
            return _buildMessageBubble(item);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  List<dynamic> _groupMessagesByTime() {
    final List<dynamic> result = [];
    DateTime? lastTime;

    for (final message in _messages) {
      final messageTime =
          DateTime.tryParse(message.createdAt) ?? DateTime.now();
      final label = _formatTimeLabel(messageTime);

      if (lastTime == null || _shouldShowTimeLabel(lastTime, messageTime)) {
        result.add(label);
        lastTime = messageTime;
      }
      result.add(message);
    }

    return result;
  }

  bool _shouldShowTimeLabel(DateTime last, DateTime current) {
    return current.difference(last).inMinutes > 5;
  }

  String _formatTimeLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDay == yesterday) {
      return '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildTimeLabel(String label) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: MobileTheme.textTertiary,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(DirectMessageItem message) {
    final isMe = message.fromMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            // 对方头像
            CircleAvatar(
              radius: 16,
              backgroundColor: MobileTheme.primary.withValues(alpha: 0.1),
              child: Text(
                (widget.peerName ?? '用户').substring(0, 1),
                style: const TextStyle(
                  fontSize: 12,
                  color: MobileTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 消息气泡
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? MobileTheme.primary : MobileTheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? Colors.white : MobileTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),

                // 发送状态
                if (isMe)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.deliveryStatus == 'sending'
                              ? '发送中...'
                              : message.deliveryStatus == 'failed'
                                  ? '点击重试'
                                  : '',
                          style: TextStyle(
                            fontSize: 11,
                            color: message.deliveryStatus == 'failed'
                                ? MobileTheme.error
                                : MobileTheme.textTertiary,
                          ),
                        ),
                        if (message.deliveryStatus == 'failed')
                          GestureDetector(
                            onTap: () => _retrySend(message),
                            child: const Text(
                              ' 重试',
                              style: TextStyle(
                                fontSize: 11,
                                color: MobileTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _retrySend(DirectMessageItem failedMessage) {
    // 移除失败消息并重新发送
    setState(() {
      _messages.removeWhere((m) => m.id == failedMessage.id);
    });
    _messageController.text = failedMessage.content;
    _handleSend();
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: MobileTheme.surface,
        border: const Border(
          top: BorderSide(color: MobileTheme.divider, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 表情栏
            if (_showEmoji) _buildEmojiBar(),

            // 输入框
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 表情按钮
                  GestureDetector(
                    onTap: _toggleEmoji,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        _showEmoji
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                        color: MobileTheme.textSecondary,
                        size: 26,
                      ),
                    ),
                  ),

                  // 输入框
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 120,
                        minHeight: 36,
                      ),
                      decoration: BoxDecoration(
                        color: MobileTheme.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                          fontSize: 16,
                          color: MobileTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: '输入消息...',
                          hintStyle: TextStyle(
                            color: MobileTheme.textTertiary,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onTap: () {
                          if (_showEmoji) {
                            setState(() {
                              _showEmoji = false;
                            });
                          }
                        },
                        onChanged: (value) {
                          setState(() {}); // 刷新发送按钮状态
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 发送按钮
                  GestureDetector(
                    onTap: _canSend() ? _handleSend : null,
                    child: Container(
                      width: 44,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _canSend()
                            ? MobileTheme.primary
                            : MobileTheme.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canSend() {
    return _messageController.text.trim().isNotEmpty && !_isSending;
  }

  Widget _buildEmojiBar() {
    final emojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '🤣',
      '😂',
      '🙂',
      '😉',
      '😊',
      '😇',
      '🥰',
      '😍',
      '🤩',
      '😘',
      '😋',
      '😛',
      '😜',
      '🤪',
      '😝',
      '🤗',
      '🤭',
      '🤫',
      '🤔',
      '🤐',
      '🤨',
      '😐',
      '😑',
      '😶',
      '😏',
      '😒',
      '🙄',
      '😬',
      '😮‍💨',
      '🤥',
      '😌',
      '😔',
      '😪',
      '🤤',
      '😴',
      '😷',
      '🤒',
      '🤕',
      '🤢',
      '🤮',
      '🤧',
      '🥵',
      '🥶',
      '🥴',
      '😵',
      '🤯',
      '🤠',
      '🥳',
      '😎',
      '🤓',
      '😕',
      '😟',
      '🙁',
      '😮',
      '😯',
      '😲',
      '😳',
      '🥺',
      '😦',
      '😧',
      '😨',
      '😰',
      '😥',
      '😢',
      '😭',
      '😱',
      '👍',
      '👎',
      '👏',
      '🙌',
      '🤝',
      '🙏',
      '💪',
      '🤘',
    ];

    return Container(
      height: 200,
      decoration: const BoxDecoration(
        color: MobileTheme.surface,
        border: Border(
          top: BorderSide(color: MobileTheme.divider, width: 0.5),
        ),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          childAspectRatio: 1,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _onTapEmoji(emojis[index]),
            child: Center(
              child: Text(
                emojis[index],
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MobileTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: MobileTheme.error),
              title: const Text('删除会话'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteConversation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: MobileTheme.error),
              title: const Text('屏蔽对方'),
              onTap: () {
                Navigator.pop(context);
                _confirmBlockUser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_outlined,
                  color: MobileTheme.primary),
              title: const Text('查看对方主页'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 导航到用户主页
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteConversation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除会话'),
        content: const Text('确定要删除这个会话吗？删除后双方聊天记录都将消失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final messageRepo = ref.read(messageRepositoryProvider);
                await messageRepo.deleteConversation(widget.conversationId);
                if (mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('会话已删除')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _confirmBlockUser() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('屏蔽对方'),
        content: const Text('确定要屏蔽对方吗？屏蔽后对方将无法给你发送消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final messageRepo = ref.read(messageRepositoryProvider);
                await messageRepo.updateConversationBlock(
                  conversationId: widget.conversationId,
                  block: true,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已屏蔽对方')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('操作失败: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
            child: const Text('屏蔽'),
          ),
        ],
      ),
    );
  }
}
