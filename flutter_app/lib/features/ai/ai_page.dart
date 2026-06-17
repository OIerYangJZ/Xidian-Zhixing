import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AiChatPage()),
            );
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
  AiConfig _config = const AiConfig();

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
    final AiConfig config = await AiConfig.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _config = config;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool configured = _config.configured;
    return Scaffold(
      appBar: AppBar(
        title: Text(configured ? '当前模型：${_config.model}' : 'AI 助手'),
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
                        hintText: configured ? '输入问题...' : '请先配置 AI 接口与模型',
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
      final AiChatResponse response = await ref.read(aiRepositoryProvider).sendMessage(
            content: text,
            apiKey: _config.apiKey,
            baseUrl: _config.baseUrl,
            model: _config.model,
            knowledgeBase: _config.knowledgeBase,
            includePosts: _config.includePosts,
            messages: _messages,
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$error')),
        );
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

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _knowledgeController = TextEditingController();
  bool _includePosts = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _knowledgeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AiConfig config = await AiConfig.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _apiKeyController.text = config.apiKey;
      _baseUrlController.text = config.baseUrl;
      _modelController.text = config.model;
      _knowledgeController.text = config.knowledgeBase;
      _includePosts = config.includePosts;
    });
  }

  Future<void> _save() async {
    await AiConfig(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      knowledgeBase: _knowledgeController.text.trim(),
      includePosts: _includePosts,
    ).save();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API Key'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(labelText: 'Base URL'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(labelText: '模型'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _knowledgeController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(labelText: '知识库'),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _includePosts,
            onChanged: (bool value) {
              setState(() {
                _includePosts = value;
              });
            },
            title: const Text('包含公开帖子'),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _save, child: const Text('保存')),
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
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          if (!user) const _AiAvatar(label: '印'),
          Flexible(
            child: Container(
              margin: EdgeInsets.only(left: user ? 48 : 10, right: user ? 10 : 48),
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
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.86),
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

class AiConfig {
  const AiConfig({
    this.apiKey = '',
    this.baseUrl = '',
    this.model = '',
    this.knowledgeBase = '',
    this.includePosts = true,
  });

  static const String storageKey = 'aiProviderConfig';

  final String apiKey;
  final String baseUrl;
  final String model;
  final String knowledgeBase;
  final bool includePosts;

  bool get configured =>
      apiKey.trim().isNotEmpty &&
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  static Future<AiConfig> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AiConfig(
      apiKey: prefs.getString('ai_api_key') ?? '',
      baseUrl: prefs.getString('ai_base_url') ?? '',
      model: prefs.getString('ai_model') ?? '',
      knowledgeBase: prefs.getString('ai_knowledge_base') ?? '',
      includePosts: prefs.getBool('ai_include_posts') ?? true,
    );
  }

  Future<void> save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_api_key', apiKey);
    await prefs.setString('ai_base_url', baseUrl);
    await prefs.setString('ai_model', model);
    await prefs.setString('ai_knowledge_base', knowledgeBase);
    await prefs.setBool('ai_include_posts', includePosts);
  }
}
