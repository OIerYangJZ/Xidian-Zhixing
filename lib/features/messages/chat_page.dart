import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../profile/public_user_profile_page.dart';
import '../../models/conversation_item.dart';
import '../../models/direct_message_item.dart';
import '../../repositories/app_repositories.dart';
import '../../widgets/emoji/emoji_assistant_bar.dart';

typedef ConversationFlagsChanged =
    void Function({bool? blockedByMe, bool? blockedByPeer});

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversation,
    this.onMessageSent,
    this.onConversationRead,
    this.onConversationRemoved,
    this.onConversationFlagsChanged,
    this.peerUserId,
  });

  final ConversationItem conversation;
  final ValueChanged<String>? onMessageSent;
  final VoidCallback? onConversationRead;
  final VoidCallback? onConversationRemoved;
  final ConversationFlagsChanged? onConversationFlagsChanged;
  final String? peerUserId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late ConversationItem _conversation;
  List<DirectMessageItem> _messages = const <DirectMessageItem>[];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _lastFailedContent;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _loading || _sending;
    final bool blockedByMe = _conversation.blockedByMe;
    final bool blockedByPeer = _conversation.blockedByPeer;
    final bool inputEnabled = !_sending && !blockedByMe && !blockedByPeer;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: widget.peerUserId != null
              ? () => _navigateToProfile(context, widget.peerUserId!)
              : null,
          child: Row(
            children: <Widget>[
              _buildAvatar(_conversation.avatarUrl, _conversation.name),
              const SizedBox(width: 8),
              Expanded(child: Text(_conversation.name)),
            ],
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _loadMessages,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              switch (value) {
                case 'profile':
                  if (widget.peerUserId != null) {
                    _navigateToProfile(context, widget.peerUserId!);
                  }
                  break;
                case 'block':
                  _toggleBlock(true);
                  break;
                case 'unblock':
                  _toggleBlock(false);
                  break;
                case 'delete':
                  _deleteConversation();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              if (widget.peerUserId != null)
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Text('查看对方主页'),
                ),
              PopupMenuItem<String>(
                value: _conversation.blockedByMe ? 'unblock' : 'block',
                child: Text(
                    _conversation.blockedByMe ? '取消屏蔽' : '屏蔽对方'),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('删除会话'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFFFF4E5),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFF9A3412)),
                    ),
                  ),
                  if (_lastFailedContent != null && !_loading)
                    TextButton(
                      onPressed:
                          _sending ? null : () => _send(_lastFailedContent),
                      child: const Text('重试发送'),
                    ),
                  TextButton(
                    onPressed: _loading ? null : _loadMessages,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          if (blockedByMe || blockedByPeer)
            _buildBlockBanner(
                blockedByMe: blockedByMe, blockedByPeer: blockedByPeer),
          Expanded(child: _buildMessageList()),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: Color(0xFFE5ECF2))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      enabled: inputEnabled,
                      decoration: InputDecoration(
                        hintText: blockedByPeer
                            ? '对方已屏蔽你，暂时无法发送消息'
                            : blockedByMe
                                ? '你已屏蔽对方，解除屏蔽后可继续发送'
                                : '输入消息',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  EmojiAssistantBar(
                    controller: _inputController,
                    compact: true,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: busy || !inputEnabled ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    tooltip: '发送',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfilePage(userId: userId),
      ),
    );
  }

  void _showMessageActions(BuildContext context, DirectMessageItem message) {
    final bool isMe = message.fromMe;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制'),
              onTap: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(ClipboardData(text: message.content));
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _messages =
                        _messages.where((m) => m.id != message.id).toList();
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error == null ? '还没有消息，先打个招呼吧。' : '消息加载失败，请重试。',
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (BuildContext context, int index) {
        final DirectMessageItem message = _messages[index];
        return Align(
          alignment: message.fromMe
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => _showMessageActions(context, message),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: message.fromMe
                    ? const Color(0xFF155E75).withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF155E75).withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!message.fromMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderAlias,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF155E75),
                        ),
                      ),
                    ),
                  Text(message.content),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        message.timeText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      if (message.fromMe) ...<Widget>[
                        const SizedBox(width: 6),
                        Text(
                          message.isRead ? '已读' : '未读',
                          style: TextStyle(
                            fontSize: 11,
                            color: message.isRead
                                ? const Color(0xFF0F766E)
                                : Colors.black45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlockBanner({
    required bool blockedByMe,
    required bool blockedByPeer,
  }) {
    final String text = blockedByPeer
        ? '对方已屏蔽你，当前只能查看历史消息。'
        : '你已屏蔽对方，解除后才可继续发送。';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFF3F4F6),
      child: Row(
        children: <Widget>[
          const Icon(Icons.shield_outlined,
              size: 18, color: Color(0xFF475569)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF334155)),
            ),
          ),
          if (blockedByMe && !blockedByPeer)
            TextButton(
              onPressed: _sending ? null : () => _toggleBlock(false),
              child: const Text('取消屏蔽'),
            ),
        ],
      ),
    );
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
        _conversation = _conversation.copyWith(
            unreadCount: 0, hasUnread: false);
      });
      widget.onConversationRead?.call();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '消息加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _send([String? retryContent]) async {
    final String content = (retryContent ?? _inputController.text).trim();
    if (content.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final DirectMessageItem created =
          await AppRepositories.messages.sendConversationMessage(
        conversationId: widget.conversation.id,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _messages = <DirectMessageItem>[..._messages, created];
        _lastFailedContent = null;
        _inputController.clear();
      });
      widget.onMessageSent?.call(created.content);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastFailedContent = content;
        _error = '发送失败：$error';
      });
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
    setState(() {
      _error = null;
    });
    try {
      final ConversationItem updated =
          await AppRepositories.messages.updateConversationBlock(
        conversationId: _conversation.id,
        block: block,
      );
      if (!mounted) return;
      setState(() {
        _conversation = _conversation.copyWith(
          blockedByMe: updated.blockedByMe,
          blockedByPeer: updated.blockedByPeer,
        );
      });
      widget.onConversationFlagsChanged?.call(
        blockedByMe: updated.blockedByMe,
        blockedByPeer: updated.blockedByPeer,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(block ? '已屏蔽对方' : '已取消屏蔽')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '操作失败：$error';
      });
    }
  }

  Future<void> _deleteConversation() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除会话'),
          content: const Text('删除后仅从你的列表中移除，会话历史不会立即物理删除。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppRepositories.messages
          .deleteConversation(_conversation.id);
      if (!mounted) return;
      widget.onConversationRemoved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('会话已删除')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '删除会话失败：$error';
      });
    }
  }

  Widget _buildAvatar(String avatarUrl, String name) {
    final String resolved = AppConfig.resolveUrl(avatarUrl);
    final String fallback =
        name.trim().isEmpty ? '?' : name.trim().substring(0, 1);
    if (resolved.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFFE5EAF3),
        child: ClipOval(
          child: Image.network(
            resolved,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Text(
              fallback,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 14,
      child: Text(fallback, style: const TextStyle(fontSize: 12)),
    );
  }
}
