import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../repositories/ai_repository.dart';

class AiPage extends ConsumerStatefulWidget {
  const AiPage({super.key});

  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage> {
  @override
  Widget build(BuildContext context) => const AiChatPage(embedded: true);
}

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiMessage> _messages = <AiMessage>[];
  bool _sending = false;
  bool _loadingConfig = true;
  String? _configError;
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
    try {
      final AiServerStatus status = await ref
          .read(aiRepositoryProvider)
          .fetchStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _configError = status.configured ? null : '校园 AI 暂时不可用';
        _loadingConfig = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _configError = '校园 AI 暂时不可用';
        _loadingConfig = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool configured =
        !_loadingConfig && _configError == null && _status.configured;
    final Widget content = Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.readingMaxWidth,
              ),
              child: _loadingConfig
                  ? const Center(child: CircularProgressIndicator())
                  : _configError != null
                  ? AppStatePanel(
                      icon: Icons.cloud_off_outlined,
                      title: _configError!,
                      message: '请稍后再试。',
                      action: TextButton(
                        onPressed: _loadConfig,
                        child: const Text('重试'),
                      ),
                    )
                  : _messages.isEmpty && !_sending
                  ? const AppStatePanel(
                      icon: Icons.auto_awesome_outlined,
                      title: '开始一次可核对的问答',
                      message: '回答中使用的校园资料会在下方标注来源。',
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == _messages.length) {
                          return const _MessageBubble(
                            role: 'assistant',
                            content: '正在查找相关资料…',
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
                    decoration: AppInput.inlineComposerDecoration(
                      hintText: configured ? '输入问题' : '暂时无法使用',
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
    );
    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: const AppPageTopActions(leading: BackButton()),
      body: content,
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
        duration: AppMotion.resolve(context, AppMotion.page),
        curve: AppMotion.settle,
      );
    });
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
    final EditorialColors colors = EditorialColors.of(context);
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
                color: user ? colors.primary : colors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    content,
                    style: TextStyle(
                      color: user ? colors.onDarkPanel : colors.ink,
                      height: 1.55,
                    ),
                  ),
                  if (references.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text('参考来源', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    for (final MapEntry<int, AiReference> entry
                        in references.asMap().entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          '${entry.key + 1}. ${entry.value.type} · ${entry.value.title}',
                          style: TextStyle(color: colors.primary, fontSize: 12),
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
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primarySubtle,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
