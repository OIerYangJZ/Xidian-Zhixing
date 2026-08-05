import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/network/api_exception.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../repositories/ai_repository.dart';

class AiPage extends ConsumerStatefulWidget {
  const AiPage({super.key});

  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage> {
  @override
  Widget build(BuildContext context) {
    return AppPageFrame(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool expanded = constraints.maxWidth >= AppBreakpoints.medium;
          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: <Widget>[
              AppSectionHeader(
                title: '校园 AI 助手',
                subtitle: '基于校园知识库与审核通过的公开内容回答',
                trailing: OutlinedButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('设置'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (expanded)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: _AiStartCard(onOpenChat: _openChat),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    const Expanded(flex: 2, child: _AiPrinciplesCard()),
                  ],
                )
              else
                Column(
                  children: <Widget>[
                    _AiStartCard(onOpenChat: _openChat),
                    const SizedBox(height: AppSpacing.lg),
                    const _AiPrinciplesCard(),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  void _openChat() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AiChatPage()));
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()));
  }
}

class _AiStartCard extends StatelessWidget {
  const _AiStartCard({required this.onOpenChat});

  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      highlighted: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppSealMark(label: '问', size: 46),
          const SizedBox(height: AppSpacing.lg),
          Text('从一个校园问题开始', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '进入对话后可询问办事流程、校园服务或公开社区内容。回答若引用资料，会在正文下方逐条列出来源。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: onOpenChat,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('发起新对话'),
          ),
        ],
      ),
    );
  }
}

class _AiPrinciplesCard extends StatelessWidget {
  const _AiPrinciplesCard();

  @override
  Widget build(BuildContext context) {
    return const AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionTitle(title: '回答原则'),
          SizedBox(height: AppSpacing.sm),
          _AiPrinciple(
            icon: Icons.source_outlined,
            title: '来源可核对',
            message: '检索到的参考资料会和回答分开呈现。',
          ),
          _AiPrinciple(
            icon: Icons.visibility_outlined,
            title: '能力边界透明',
            message: '服务器未配置时会明确提示，不生成替代回答。',
          ),
          _AiPrinciple(
            icon: Icons.lock_outline_rounded,
            title: '公开内容范围',
            message: '论坛内容仅使用审核通过的公开帖子。',
          ),
        ],
      ),
    );
  }
}

class _AiPrinciple extends StatelessWidget {
  const _AiPrinciple({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
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
  AiServerStatus _status = const AiServerStatus(
    model: '',
    models: <String>[],
    problem: AiStatusProblem.loading,
  );

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
    setState(() {
      _status = const AiServerStatus(
        model: '',
        models: <String>[],
        problem: AiStatusProblem.loading,
      );
    });
    final AiServerStatus status = await ref
        .read(aiRepositoryProvider)
        .fetchStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Locale locale = Localizations.localeOf(context);
    final bool configured = _status.configured;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          configured
              ? uiText(
                  context,
                  zh: '当前模型：${_status.model}',
                  en: 'Model: ${_status.model}',
                )
              : uiText(context, zh: 'AI 助手', en: 'AI assistant'),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: uiText(context, zh: 'AI 设置', en: 'AI settings'),
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
          if (!configured && !_status.isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppInlineMessage(
                title: _status.problemTitleFor(locale),
                message: _status.problemMessageFor(locale),
                tone: _status.problem == AiStatusProblem.unauthorized
                    ? AppMessageTone.warning
                    : AppMessageTone.error,
                action: TextButton(
                  onPressed: _loadConfig,
                  child: Text(uiText(context, zh: '重试', en: 'Retry')),
                ),
              ),
            ),
          if (!configured &&
              !_status.isLoading &&
              _status.diagnosticLine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  _status.diagnosticLine,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.readingMaxWidth,
                ),
                child: _messages.isEmpty && !_sending
                    ? AppStatePanel(
                        icon: Icons.auto_awesome_outlined,
                        title: uiText(
                          context,
                          zh: '开始一次可核对的问答',
                          en: 'Start a question you can verify',
                        ),
                        message: uiText(
                          context,
                          zh: '回答中使用的校园资料会在下方标注来源。',
                          en: 'Sources used in the answer are listed below it.',
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == _messages.length) {
                            return _MessageBubble(
                              role: 'assistant',
                              content: uiText(
                                context,
                                zh: '正在查找相关资料…',
                                en: 'Looking up sources…',
                              ),
                              references: const <AiReference>[],
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
                      decoration: InputDecoration(
                        hintText: configured
                            ? uiText(
                                context,
                                zh: '输入问题...',
                                en: 'Ask a question...',
                              )
                            : _status.problemTitleFor(locale),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _sending || !configured ? null : _send,
                    child: Text(uiText(context, zh: '发送', en: 'Send')),
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
    } on ApiException catch (error) {
      // Keep the status code visible: 401, 503 and 502 need very different fixes.
      final String code = error.statusCode == null
          ? ''
          : uiTextGlobal(
              zh: '（HTTP ${error.statusCode}）',
              en: ' (HTTP ${error.statusCode})',
            );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiTextGlobal(
                zh: '发送失败$code：${error.message}',
                en: 'Send failed$code: ${error.message}',
              ),
            ),
          ),
        );
      }
      unawaited(_loadConfig());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiTextGlobal(
                zh: '发送失败：$error',
                en: 'Send failed: $error',
              ),
            ),
          ),
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

class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  AiServerStatus _status = const AiServerStatus(
    model: '',
    models: <String>[],
    problem: AiStatusProblem.loading,
  );
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = const AiServerStatus(
        model: '',
        models: <String>[],
        problem: AiStatusProblem.loading,
      );
    });
    final AiServerStatus status = await ref
        .read(aiRepositoryProvider)
        .fetchStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Locale locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: 'AI 设置', en: 'AI settings')),
      ),
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
            title: Text(uiText(context, zh: '服务器 AI', en: 'Server AI')),
            subtitle: Text(_status.problemTitleFor(locale)),
          ),
          if (!_status.configured && !_status.isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppInlineMessage(
                title: uiText(context, zh: '如何修复', en: 'How to fix'),
                message: _status.problemMessageFor(locale),
                tone: _status.problem == AiStatusProblem.unauthorized
                    ? AppMessageTone.warning
                    : AppMessageTone.error,
              ),
            ),
          if (!_status.configured &&
              !_status.isLoading &&
              _status.diagnosticLine.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                uiText(context, zh: '服务器返回', en: 'Server response'),
              ),
              subtitle: SelectableText(_status.diagnosticLine),
            ),
          if (_status.configured)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(uiText(context, zh: '当前模型', en: 'Current model')),
              subtitle: Text(_status.model),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              uiText(context, zh: '校园知识库', en: 'Campus knowledge base'),
            ),
            subtitle: Text(
              uiText(
                context,
                zh: '由服务器统一维护并建立索引',
                en: 'Maintained and indexed on the server',
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              uiText(context, zh: '论坛公开帖子', en: 'Public forum posts'),
            ),
            subtitle: Text(
              uiText(
                context,
                zh: '审核通过后自动进入检索',
                en: 'Indexed automatically once approved',
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              _loading
                  ? uiText(context, zh: '读取中', en: 'Loading')
                  : uiText(context, zh: '刷新状态', en: 'Refresh status'),
            ),
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
                borderRadius: BorderRadius.circular(AppRadii.large),
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
                    Text('参考来源', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    for (final MapEntry<int, AiReference> entry
                        in references.asMap().entries)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(color: SharedColors.divider),
                          borderRadius: BorderRadius.circular(AppRadii.small),
                        ),
                        child: Text(
                          '${entry.key + 1}. ${entry.value.type} · ${entry.value.title}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
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
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
