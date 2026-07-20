import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../core/theme/shared_colors.dart';
import '../../repositories/ai_repository.dart';

class AiPage extends ConsumerStatefulWidget {
  const AiPage({super.key});

  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: <Widget>[
        FilledButton.icon(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const AiChatPage()));
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('发起新对话'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()),
            );
          },
          child: const Text('AI 设置'),
        ),
        const SizedBox(height: 28),
        Container(
          height: 260,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SharedColors.divider),
          ),
          child: const Text('还没有对话'),
        ),
      ],
    );
  }
}

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiMessage> _messages = <AiMessage>[];
  bool _sending = false;
  AiServerStatus _status = const AiServerStatus(model: '', models: <String>[]);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadConfig);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    AiServerStatus status;
    try {
      status = await ref.read(aiRepositoryProvider).fetchStatus();
    } catch (_) {
      status = const AiServerStatus(model: '', models: <String>[]);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool configured = _status.configured;
    return Scaffold(
      appBar: AppBar(
        title: Text(configured ? '当前模型：${_status.model}' : 'AI 助手'),
        actions: <Widget>[
          IconButton(
            tooltip: 'AI 设置',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()),
              );
              await _loadConfig();
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (index == _messages.length) {
                  return const _MessageBubble(
                    role: 'assistant',
                    content: '...',
                    references: <AiReference>[],
                  );
                }
                final AiMessage message = _messages[index];
                return _MessageBubble(
                  role: message.role,
                  content: message.content,
                  references: message.references,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_sending && configured,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: configured ? '输入问题...' : '服务器 AI 尚未配置',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _sending || !configured ? null : _send,
                    child: const Text('发送'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _inputController.clear();
    setState(() {
      _messages.add(AiMessage(role: 'user', content: text));
      _sending = true;
    });
    _scrollToBottom();
    try {
      final AiChatResponse response = await ref
          .read(aiRepositoryProvider)
          .sendMessage(content: text, messages: _messages);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          AiMessage(
            role: 'assistant',
            content: response.answer,
            references: response.references,
          ),
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
        _scrollToBottom();
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}

class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  AiServerStatus _status = const AiServerStatus(model: '', models: <String>[]);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final AiServerStatus status = await ref
          .read(aiRepositoryProvider)
          .fetchStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = const AiServerStatus(model: '', models: <String>[]),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _status.configured
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
            ),
            title: const Text('服务器 AI'),
            subtitle: Text(_status.configured ? '已启用' : '尚未配置'),
          ),
          if (_status.configured)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('当前模型'),
              subtitle: Text(_status.model),
            ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('校园知识库'),
            subtitle: Text('由服务器统一维护并建立索引'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('论坛公开帖子'),
            subtitle: Text('审核通过后自动进入检索'),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_loading ? '读取中' : '刷新状态'),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.role,
    required this.content,
    required this.references,
  });

  final String role;
  final String content;
  final List<AiReference> references;

  @override
  Widget build(BuildContext context) {
    final bool user = role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: user
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: <Widget>[
          if (!user) const _AiAvatar(label: '印'),
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                left: user ? 48 : 10,
                right: user ? 10 : 48,
              ),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: user
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: user ? null : Border.all(color: SharedColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    content,
                    style: TextStyle(
                      color: user ? Colors.white : null,
                      height: 1.55,
                    ),
                  ),
                  if (references.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    for (final AiReference ref in references)
                      Text(
                        '${ref.type} · ${ref.title}',
                        style: TextStyle(
                          color: user
                              ? Colors.white.withValues(alpha: 0.82)
                              : Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.86),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (user) const _AiAvatar(label: '我'),
        ],
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
