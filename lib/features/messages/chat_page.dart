import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../models/conversation_item.dart';
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
  final List<_ChatMessage> _messages = <_ChatMessage>[];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        content: widget.conversation.lastMessage,
        fromMe: false,
        time: _formatNow(),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            _buildAvatar(
                widget.conversation.avatarUrl, widget.conversation.name),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.conversation.name)),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFEFF6FB),
            child: const Text(
              '当前会话为 MVP 演示版，消息仅本地展示。',
              style: TextStyle(color: Color(0xFF155E75)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                final _ChatMessage message = _messages[index];
                return Align(
                  alignment: message.fromMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
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
                        Text(message.content),
                        const SizedBox(height: 4),
                        Text(
                          message.time,
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
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5ECF2))),
              ),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '输入消息（支持表情）',
                      suffixIcon: IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded),
                        tooltip: '发送',
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                  const SizedBox(height: 6),
                  EmojiAssistantBar(
                      controller: _inputController, compact: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    final String content = _inputController.text.trim();
    if (content.isEmpty) {
      return;
    }
    setState(() {
      _messages.add(
        _ChatMessage(
          content: content,
          fromMe: true,
          time: _formatNow(),
        ),
      );
      _inputController.clear();
    });
    widget.onMessageSent?.call(content);
  }

  String _formatNow() {
    final DateTime now = DateTime.now();
    final String hh = now.hour.toString().padLeft(2, '0');
    final String mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildAvatar(String avatarUrl, String name) {
    final String resolved = _resolveAvatarUrl(avatarUrl);
    if (resolved.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: NetworkImage(resolved),
      );
    }
    final String fallback =
        name.trim().isEmpty ? '?' : name.trim().substring(0, 1);
    return CircleAvatar(
      radius: 14,
      child: Text(
        fallback,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  String _resolveAvatarUrl(String avatarUrl) {
    final String trimmed = avatarUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      final Uri base = Uri.parse(AppConfig.apiBaseUrl);
      return '${base.scheme}://${base.authority}$trimmed';
    }
    return '';
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.content,
    required this.fromMe,
    required this.time,
  });

  final String content;
  final bool fromMe;
  final String time;
}
