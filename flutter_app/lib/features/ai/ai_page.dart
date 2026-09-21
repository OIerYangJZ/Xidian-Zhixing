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
  final TextEditingController _questionController = TextEditingController();

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  List<_ConversationPreview> _conversations = const <_ConversationPreview>[];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final dynamic decoded = _decodeJsonList(prefs.getString(_indexKey));
    if (!mounted || decoded is! List) return;
    setState(() {
      _conversations = decoded
          .whereType<Map>()
          .map(
            (dynamic value) => _ConversationPreview.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();
    });
  }

  Future<void> _openChat([String? conversationId]) async {
    final String question = conversationId == null
        ? _questionController.text.trim()
        : '';
    _questionController.clear();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiChatPage(
          conversationId: conversationId,
          initialQuestion: question,
        ),
      ),
    );
    await _loadConversations();
  }

  Future<void> _showHistory() async {
    final String? id = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          ListTile(
            title: Text(uiText(context, zh: '历史对话', en: 'Chat history')),
          ),
          if (_conversations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                uiText(context, zh: '还没有保存的对话', en: 'No saved conversations'),
              ),
            ),
          for (final _ConversationPreview item in _conversations)
            ListTile(
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
              trailing: Text(item.updatedAt),
              onTap: () => Navigator.of(context).pop(item.id),
            ),
        ],
      ),
    );
    if (id != null && mounted) await _openChat(id);
  }

  @override
  Widget build(BuildContext context) {
    final bool mobile = MediaQuery.sizeOf(context).width < 801;
    final Widget composer = _AiComposer(
      controller: _questionController,
      onSend: () => _openChat(),
      hint: uiText(context, zh: '随便问点什么', en: 'Ask anything'),
    );
    return SafeArea(
      top: false,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (mobile)
            Align(
              alignment: const Alignment(0, -0.08),
              child: _AiStar(size: 77, faded: true),
            )
          else
            Align(
              alignment: const Alignment(0, -0.12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const _AiStar(size: 52),
                          const SizedBox(width: 12),
                          Text(
                            'AI',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      composer,
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: mobile ? 8 : 24,
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: uiText(context, zh: '历史对话', en: 'Chat history'),
                  onPressed: _showHistory,
                  icon: const Icon(Icons.history_rounded),
                ),
                IconButton(
                  tooltip: uiText(context, zh: '新对话', en: 'New chat'),
                  onPressed: () => _openChat(),
                  icon: const Icon(Icons.edit_square),
                ),
              ],
            ),
          ),
          if (mobile)
            Positioned(left: 11, right: 11, bottom: 10, child: composer),
        ],
      ),
    );
  }
}

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key, this.conversationId, this.initialQuestion = ''});

  final String initialQuestion;

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

  @override
  void initState() {
    super.initState();
    _conversationId =
        widget.conversationId ??
        DateTime.now().microsecondsSinceEpoch.toString();
    if (widget.initialQuestion.isNotEmpty) {
      _inputController.text = widget.initialQuestion;
      Future<void>.microtask(_send);
    } else {
      _loadMessages();
    }
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
    final dynamic decoded = _decodeJsonList(prefs.getString(_indexKey));
    final List<_ConversationPreview> rows = decoded is List
        ? decoded
              .whereType<Map>()
              .map(
                (dynamic value) => _ConversationPreview.fromJson(
                  Map<String, dynamic>.from(value as Map),
                ),
              )
              .toList()
        : <_ConversationPreview>[];
    rows.removeWhere((item) => item.id == _conversationId);
    rows.insert(
      0,
      _ConversationPreview(
        id: _conversationId,
        title: first.content.length > 24
            ? '${first.content.substring(0, 24)}…'
            : first.content,
        preview: _messages.isEmpty ? '' : _messages.last.content,
        updatedAt: '${DateTime.now().month}/${DateTime.now().day}',
      ),
    );
    await prefs.setString(
      _indexKey,
      jsonEncode(rows.map((item) => item.toJson()).toList()),
    );
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
                    ? const Center(child: _AiStar(size: 77, faded: true))
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
                child: _AiComposer(
                  controller: _inputController,
                  enabled: !_sending,
                  onSend: _send,
                  hint: uiText(context, zh: '输入消息', en: 'Message'),
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
    setState(() {
      _messages.add(AiMessage(role: 'user', content: text));
      _sending = true;
    });
    _scrollToBottom();
    try {
      // Save the user turn before waiting on the network so a failed request
      // still remains in the conversation history.
      await _saveMessages();
      final AiChatResponse response = await ref
          .read(aiRepositoryProvider)
          .sendMessage(content: text, messages: _messages);
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
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
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
    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SelectableText(
          content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
        for (final AiReference reference in references)
          TextButton(
            onPressed: onReferenceTap == null
                ? null
                : () => onReferenceTap!(reference),
            child: Text(reference.title, textAlign: TextAlign.left),
          ),
      ],
    );
    if (!user) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 40),
        child: SizedBox(width: double.infinity, child: body),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.85),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
          ),
          child: body,
        ),
      ),
    );
  }
}

class _AiComposer extends StatelessWidget {
  const _AiComposer({
    required this.controller,
    required this.onSend,
    required this.hint,
    this.enabled = true,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool mobile = MediaQuery.sizeOf(context).width < 801;
    final Widget field = TextField(
      controller: controller,
      enabled: enabled,
      minLines: 1,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: hint,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        isDense: true,
      ),
      onSubmitted: (_) => onSend(),
    );
    final Widget send = IconButton(
      tooltip: uiText(context, zh: '发送', en: 'Send'),
      onPressed: enabled ? onSend : null,
      icon: Icon(
        enabled ? Icons.graphic_eq_rounded : Icons.stop_rounded,
        size: 20,
      ),
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.onSurface,
        foregroundColor: theme.colorScheme.surface,
        disabledBackgroundColor: theme.colorScheme.onSurface,
        disabledForegroundColor: theme.colorScheme.surface,
        shape: const CircleBorder(),
        minimumSize: const Size.square(44),
        maximumSize: const Size.square(44),
        padding: EdgeInsets.zero,
      ),
    );
    return Container(
      constraints: BoxConstraints(minHeight: mobile ? 77 : 72),
      padding: mobile
          ? const EdgeInsets.fromLTRB(14, 4, 6, 4)
          : const EdgeInsets.fromLTRB(24, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(mobile ? 23 : 60),
      ),
      child: mobile
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                field,
                Align(alignment: Alignment.centerRight, child: send),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: field),
                const SizedBox(width: 16),
                send,
              ],
            ),
    );
  }
}

class _AiStar extends StatelessWidget {
  const _AiStar({required this.size, this.faded = false});
  final double size;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _AiStarPainter(
          faded
              ? Theme.of(context).dividerColor
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _AiStarPainter extends CustomPainter {
  const _AiStarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final Path path = Path()
      ..moveTo(12, 2)
      ..lineTo(15, 9)
      ..lineTo(22, 12)
      ..lineTo(15, 15)
      ..lineTo(12, 22)
      ..lineTo(9, 15)
      ..lineTo(2, 12)
      ..lineTo(9, 9)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_AiStarPainter oldDelegate) => oldDelegate.color != color;
}

class _ConversationPreview {
  const _ConversationPreview({
    required this.id,
    required this.title,
    required this.preview,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String preview;
  final String updatedAt;

  Map<String, String> toJson() => <String, String>{
    'id': id,
    'title': title,
    'preview': preview,
    'updatedAt': updatedAt,
  };

  factory _ConversationPreview.fromJson(Map<String, dynamic> json) =>
      _ConversationPreview(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        preview: json['preview']?.toString() ?? '',
        updatedAt: json['updatedAt']?.toString() ?? '',
      );
}

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
