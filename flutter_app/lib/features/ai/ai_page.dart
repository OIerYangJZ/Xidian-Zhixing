import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/l10n/ui_text.dart';
import '../../models/post_item.dart';
import '../../repositories/ai_repository.dart';
import '../../repositories/app_repositories.dart';
import '../post/post_detail_page.dart';

const String _indexKey = 'xiaodian_conversation_index';
const String _conversationKeyPrefix = 'xiaodian_conversation_';

class AiPage extends ConsumerStatefulWidget {
  const AiPage({super.key});

  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage> {
  List<_ConversationPreview> _conversations = const <_ConversationPreview>[];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<_ConversationPreview> rows = _readIndex(prefs);
    if (!mounted) return;
    setState(() => _conversations = rows);
  }

  Future<void> _rename(_ConversationPreview item) async {
    final String? title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameChatDialog(initial: item.title),
    );
    final String trimmed = (title ?? '').trim();
    if (trimmed.isEmpty || trimmed == item.title) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _writeIndex(
      prefs,
      _readIndex(prefs)
          .map(
            (_ConversationPreview row) =>
                row.id == item.id ? row.withTitle(trimmed) : row,
          )
          .toList(),
    );
    await _loadConversations();
  }

  Future<void> _delete(_ConversationPreview item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(uiText(dialogContext, zh: '删除对话？', en: 'Delete chat?')),
        content: Text(
          uiText(
            dialogContext,
            zh: '「${item.title}」的聊天记录会从本机删除。',
            en: 'The messages in "${item.title}" are removed from this device.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(uiText(dialogContext, zh: '取消', en: 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(uiText(dialogContext, zh: '删除', en: 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_conversationKeyPrefix${item.id}');
    await _writeIndex(
      prefs,
      _readIndex(prefs)
          .where((_ConversationPreview row) => row.id != item.id)
          .toList(),
    );
    await _loadConversations();
  }

  Future<void> _openChat([String? conversationId]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiChatPage(conversationId: conversationId),
      ),
    );
    await _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            uiText(context, zh: '对话', en: 'Conversations'),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _openChat(),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(
                            uiText(context, zh: '新对话', en: 'New chat'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_conversations.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: FilledButton(
                        onPressed: () => _openChat(),
                        child: Text(
                          uiText(
                            context,
                            zh: '开始一段对话',
                            en: 'Start a conversation',
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
                    sliver: SliverList.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (BuildContext context, int index) {
                        final _ConversationPreview item = _conversations[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                          leading: const Icon(
                            Icons.chat_bubble_outline_rounded,
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(item.updatedAt),
                              PopupMenuButton<String>(
                                key: Key('ai-conversation-menu-${item.id}'),
                                tooltip: uiText(
                                  context,
                                  zh: '更多',
                                  en: 'More',
                                ),
                                onSelected: (String action) => action ==
                                        'rename'
                                    ? _rename(item)
                                    : _delete(item),
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'rename',
                                    child: Text(
                                      uiText(context, zh: '重命名', en: 'Rename'),
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text(
                                      uiText(context, zh: '删除', en: 'Delete'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _openChat(item.id),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key, this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiMessage> _messages = <AiMessage>[];
  late final String _conversationId;
  bool _sending = false;

  /// Set while an answer is generating; [_stop] cancels it on the server.
  String? _activeRequestId;

  @override
  void initState() {
    super.initState();
    _conversationId =
        widget.conversationId ??
        DateTime.now().microsecondsSinceEpoch.toString();
    _loadMessages();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final dynamic decoded = _decodeJsonList(
      prefs.getString('$_conversationKeyPrefix$_conversationId'),
    );
    if (!mounted || decoded is! List) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map((dynamic value) {
                final Map<String, dynamic> map = Map<String, dynamic>.from(
                  value as Map,
                );
                return AiMessage(
                  role: map['role']?.toString() ?? 'user',
                  content: map['content']?.toString() ?? '',
                  references: _decodeReferences(map['references']),
                );
              })
              .where((item) => item.content.isNotEmpty),
        );
    });
  }

  Future<void> _saveMessages() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_conversationKeyPrefix$_conversationId',
      jsonEncode(
        _messages
            .map(
              (item) => <String, dynamic>{
                'role': item.role,
                'content': item.content,
                'references': item.references
                    .map(
                      (reference) => <String, String>{
                        'type': reference.type,
                        'title': reference.title,
                        'targetId': reference.targetId,
                        'jumpUrl': reference.jumpUrl,
                        'sourceUrl': reference.sourceUrl,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      ),
    );
    final AiMessage first = _messages.firstWhere(
      (item) => item.role == 'user',
      orElse: () => const AiMessage(role: 'user', content: '新对话'),
    );
    final List<_ConversationPreview> rows = _readIndex(prefs);
    final _ConversationPreview? existing = rows
        .where((item) => item.id == _conversationId)
        .firstOrNull;
    rows.removeWhere((item) => item.id == _conversationId);
    final bool renamed = existing?.renamed ?? false;
    rows.insert(
      0,
      _ConversationPreview(
        id: _conversationId,
        // A renamed chat keeps the user's title.
        title: renamed
            ? existing!.title
            : first.content.length > 24
            ? '${first.content.substring(0, 24)}…'
            : first.content,
        preview: _messages.isEmpty ? '' : _messages.last.content,
        updatedAt: '${DateTime.now().month}/${DateTime.now().day}',
        renamed: renamed,
      ),
    );
    await _writeIndex(prefs, rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: uiText(context, zh: '返回', en: 'Back'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const SizedBox.shrink(),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.readingMaxWidth,
                ),
                child: _messages.isEmpty && !_sending
                    ? Center(
                        child: Text(
                          uiText(
                            context,
                            zh: '有什么可以帮你？',
                            en: 'How can I help?',
                          ),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == _messages.length) {
                            return _AiMessageView(
                              content: uiText(
                                context,
                                zh: '正在思考…',
                                en: 'Thinking…',
                              ),
                              user: false,
                              references: const <AiReference>[],
                              onReferenceTap: null,
                            );
                          }
                          final AiMessage message = _messages[index];
                          return _AiMessageView(
                            content: message.content,
                            user: message.role == 'user',
                            references: message.references,
                            onReferenceTap: _openReference,
                          );
                        },
                      ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.readingMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: uiText(context, zh: '输入消息', en: 'Message'),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_sending)
                      IconButton.filledTonal(
                        onPressed: _stop,
                        tooltip: uiText(context, zh: '停止', en: 'Stop'),
                        icon: const Icon(Icons.stop_rounded),
                      )
                    else
                      IconButton.filled(
                        onPressed: _send,
                        tooltip: uiText(context, zh: '发送', en: 'Send'),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    final String requestId = AiRepository.newRequestId();
    setState(() {
      _messages.add(AiMessage(role: 'user', content: text));
      _sending = true;
      _activeRequestId = requestId;
    });
    _scrollToBottom();
    try {
      // Save the user turn before waiting on the network so a failed request
      // still remains in the conversation history.
      await _saveMessages();
      final AiChatResponse response = await ref
          .read(aiRepositoryProvider)
          .sendMessage(
            content: text,
            messages: _messages,
            requestId: requestId,
          );
      // Stopped while waiting: the user has moved on, drop the late answer.
      if (_activeRequestId != requestId) return;
      if (mounted)
        setState(
          () => _messages.add(
            AiMessage(
              role: 'assistant',
              content: response.answer,
              references: response.references,
            ),
          ),
        );
      await _saveMessages();
    } catch (_) {
      // A stopped request fails with 409 by design; that is not an error.
      if (_activeRequestId != requestId) return;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                zh: '暂时无法回复，请稍后再试',
                en: 'Unable to reply right now. Try again later.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted && _activeRequestId == requestId) {
        setState(() {
          _sending = false;
          _activeRequestId = null;
        });
        _scrollToBottom();
      }
    }
  }

  /// Stops the answer in progress. The server cancel is what stops the model
  /// provider from generating; the UI is released immediately either way.
  Future<void> _stop() async {
    final String? requestId = _activeRequestId;
    if (requestId == null) return;
    setState(() {
      _sending = false;
      _activeRequestId = null;
    });
    try {
      await ref.read(aiRepositoryProvider).cancelChat(requestId);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                zh: '停止请求未送达，回答可能仍在生成',
                en: 'Could not reach the server to stop the answer.',
              ),
            ),
          ),
        );
    }
  }

  Future<void> _openReference(AiReference reference) async {
    if (reference.type != 'post' && reference.type != '帖子') {
      final Uri? uri = Uri.tryParse(reference.sourceUrl);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http'))
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final String postId = reference.targetId.trim();
    if (postId.isEmpty) return;
    final PostItem post = await AppRepositories.posts.fetchPostDetail(postId);
    if (mounted)
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PostDetailPage(post: post)),
      );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients)
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
    });
  }
}

class _AiMessageView extends StatelessWidget {
  const _AiMessageView({
    required this.content,
    required this.user,
    required this.references,
    required this.onReferenceTap,
  });

  final String content;
  final bool user;
  final List<AiReference> references;
  final ValueChanged<AiReference>? onReferenceTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                content,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              for (final AiReference reference in references)
                TextButton(
                  onPressed: onReferenceTap == null
                      ? null
                      : () => onReferenceTap!(reference),
                  child: Text(reference.title, textAlign: TextAlign.left),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owns its controller, so it lives until the dialog's exit animation ends.
class _RenameChatDialog extends StatefulWidget {
  const _RenameChatDialog({required this.initial});

  final String initial;

  @override
  State<_RenameChatDialog> createState() => _RenameChatDialogState();
}

class _RenameChatDialogState extends State<_RenameChatDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(uiText(context, zh: '重命名对话', en: 'Rename chat')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        onSubmitted: (String value) => Navigator.of(context).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(uiText(context, zh: '取消', en: 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(uiText(context, zh: '保存', en: 'Save')),
        ),
      ],
    );
  }
}

class _ConversationPreview {
  const _ConversationPreview({
    required this.id,
    required this.title,
    required this.preview,
    required this.updatedAt,
    this.renamed = false,
  });

  final String id;
  final String title;
  final String preview;
  final String updatedAt;

  /// Set once the user renames it; the title then stops following the
  /// first message.
  final bool renamed;

  _ConversationPreview withTitle(String value) => _ConversationPreview(
    id: id,
    title: value,
    preview: preview,
    updatedAt: updatedAt,
    renamed: true,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'preview': preview,
    'updatedAt': updatedAt,
    if (renamed) 'renamed': true,
  };

  factory _ConversationPreview.fromJson(Map<String, dynamic> json) =>
      _ConversationPreview(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        preview: json['preview']?.toString() ?? '',
        updatedAt: json['updatedAt']?.toString() ?? '',
        renamed: json['renamed'] == true,
      );
}

List<_ConversationPreview> _readIndex(SharedPreferences prefs) {
  final dynamic decoded = _decodeJsonList(prefs.getString(_indexKey));
  if (decoded is! List) {
    return <_ConversationPreview>[];
  }
  return decoded
      .whereType<Map>()
      .map(
        (dynamic value) => _ConversationPreview.fromJson(
          Map<String, dynamic>.from(value as Map),
        ),
      )
      .where((_ConversationPreview item) => item.id.isNotEmpty)
      .toList();
}

Future<void> _writeIndex(
  SharedPreferences prefs,
  List<_ConversationPreview> rows,
) => prefs.setString(
  _indexKey,
  jsonEncode(rows.map((_ConversationPreview item) => item.toJson()).toList()),
);

dynamic _decodeJsonList(String? value) {
  if (value == null || value.trim().isEmpty) {
    return const <dynamic>[];
  }
  try {
    return jsonDecode(value);
  } on FormatException {
    return const <dynamic>[];
  }
}

List<AiReference> _decodeReferences(dynamic value) {
  if (value is! List) {
    return const <AiReference>[];
  }
  return value
      .whereType<Map>()
      .map(
        (dynamic item) =>
            AiReference.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .where((AiReference item) => item.title.isNotEmpty)
      .toList();
}
