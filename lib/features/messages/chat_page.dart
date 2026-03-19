import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../models/conversation_item.dart';
import '../../models/direct_message_item.dart';
import '../../repositories/app_repositories.dart';
import '../../widgets/emoji/emoji_assistant_bar.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversation,
    this.onMessageSent,
  });

  final ConversationItem conversation;
  final ValueChanged<String>? onMessageSent;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<DirectMessageItem> _messages = const <DirectMessageItem>[];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            _buildAvatar(
              widget.conversation.avatarUrl,
              widget.conversation.name,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.conversation.name)),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _loadMessages,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
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
                  TextButton(
                    onPressed: _loading ? null : _loadMessages,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildMessageList(),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5ECF2))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !_sending,
                      decoration: const InputDecoration(
                        hintText: '输入消息',
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
                    onPressed: busy ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
          alignment:
              message.fromMe ? Alignment.centerRight : Alignment.centerLeft,
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
                Text(
                  message.timeText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = messages;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
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

  Future<void> _send() async {
    final String content = _inputController.text.trim();
    if (content.isEmpty || _sending) {
      return;
    }
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
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = <DirectMessageItem>[..._messages, created];
        _inputController.clear();
      });
      widget.onMessageSent?.call(created.content);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
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
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
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
      child: Text(
        fallback,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
