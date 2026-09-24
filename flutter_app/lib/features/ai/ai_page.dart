import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/campus_text.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/network/api_exception.dart';
import '../../core/state/app_providers.dart';
import '../../design_system/design_system.dart';
import '../../models/post_item.dart';
import '../../repositories/ai_repository.dart';
import '../../repositories/app_repositories.dart';
import '../post/post_detail_page.dart';

const String _indexKey = 'xiaodian_conversation_index';
const String _conversationKeyPrefix = 'xiaodian_conversation_';

/// 校园 AI (handoff AI1–AI4). History lives on this device. At
/// [_splitMinWidth] and wider the history sits beside the open chat;
/// narrower, the history is the page and a chat opens as its own route.
class AiPage extends ConsumerStatefulWidget {
  const AiPage({super.key});

  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage> {
  static const double _splitMinWidth = 960;

  List<_ConversationPreview> _conversations = const <_ConversationPreview>[];
  final TextEditingController _search = TextEditingController();

  /// The chat open in the wide layout; a fresh id means a new chat.
  String _selectedId = _newId();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadConversations();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<_ConversationPreview> rows = _readIndex(prefs);
    if (!mounted) return;
    setState(() => _conversations = rows);
  }

  Future<void> _rename(_ConversationPreview item) async {
    if (await _renameConversation(context, item.id, item.title)) {
      await _loadConversations();
    }
  }

  Future<void> _delete(_ConversationPreview item) async {
    if (await _deleteConversation(context, item.id, item.title)) {
      if (_selectedId == item.id) setState(() => _selectedId = _newId());
      await _loadConversations();
    }
  }

  Future<void> _openChat({required bool split, String? conversationId}) async {
    if (split) {
      setState(() => _selectedId = conversationId ?? _newId());
      return;
    }
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
      body: ZxPaper(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool split = constraints.maxWidth >= _splitMinWidth;
            final Widget history = _buildHistory(split: split);
            if (!split) return SafeArea(child: history);
            final ZxTokens t = ZxTokens.of(context);
            return Row(
              children: <Widget>[
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: t.surface,
                    border: Border(right: BorderSide(color: t.line)),
                  ),
                  child: history,
                ),
                Expanded(
                  child: AiChatPage(
                    key: ValueKey<String>(_selectedId),
                    conversationId: _selectedId,
                    embedded: true,
                    onChanged: _loadConversations,
                    onDeleted: () {
                      setState(() => _selectedId = _newId());
                      _loadConversations();
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistory({required bool split}) {
    final ZxTokens t = ZxTokens.of(context);
    final String query = _search.text.trim().toLowerCase();
    final List<_ConversationPreview> rows = query.isEmpty
        ? _conversations
        : _conversations
              .where(
                (_ConversationPreview c) =>
                    c.title.toLowerCase().contains(query) ||
                    c.preview.toLowerCase().contains(query),
              )
              .toList();
    final Map<_Age, List<_ConversationPreview>> groups =
        <_Age, List<_ConversationPreview>>{};
    for (final _ConversationPreview row in rows) {
      groups.putIfAbsent(row.age, () => <_ConversationPreview>[]).add(row);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        split ? 14 : 16,
        split ? 20 : 16,
        split ? 14 : 16,
        40,
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  uiText(context, zh: '校园 AI', en: 'Campus AI'),
                  style: ZxType.headline.copyWith(color: t.text),
                ),
              ),
            ],
          ),
        ),
        ZxButton(
          key: const Key('ai-new-chat'),
          label: uiText(context, zh: '新对话', en: 'New chat'),
          icon: Icons.add_rounded,
          expand: true,
          onPressed: () => _openChat(split: split),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('ai-history-search'),
          controller: _search,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            hintText: uiText(context, zh: '搜索历史对话', en: 'Search chats'),
          ),
        ),
        const SizedBox(height: 8),
        if (_conversations.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: ZxStatePanel(
              icon: Icons.auto_awesome_outlined,
              title: uiText(context, zh: '还没有对话', en: 'No chats yet'),
              message: uiText(
                context,
                zh: '问问小电校园里的事：开放时间、办事流程、规章制度',
                en: 'Ask about opening hours, procedures and campus rules.',
              ),
            ),
          )
        else if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              uiText(context, zh: '没有匹配的对话', en: 'No matching chats'),
              textAlign: TextAlign.center,
              style: ZxType.caption.copyWith(color: t.text3),
            ),
          ),
        for (final _Age age in _Age.values)
          if (groups[age] != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
              child: Text(
                switch (age) {
                  _Age.today => uiText(context, zh: '今天', en: 'Today'),
                  _Age.week => uiText(context, zh: '本周', en: 'This week'),
                  _Age.older => uiText(context, zh: '更早', en: 'Earlier'),
                },
                style: ZxType.caption.copyWith(
                  color: t.text3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final _ConversationPreview item in groups[age]!)
              _historyRow(item, split: split),
          ],
      ],
    );
  }

  Widget _historyRow(_ConversationPreview item, {required bool split}) {
    final ZxTokens t = ZxTokens.of(context);
    final bool selected = split && item.id == _selectedId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? t.primarySoft : Colors.transparent,
        borderRadius: ZxRadius.buttonAll,
        child: InkWell(
          borderRadius: ZxRadius.buttonAll,
          onTap: () => _openChat(split: split, conversationId: item.id),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: ZxRadius.buttonAll,
                    border: Border(
                      left: BorderSide(color: t.primary, width: 3),
                    ),
                  )
                : null,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZxType.label.copyWith(color: t.text),
                      ),
                      if (!split && item.preview.isNotEmpty)
                        Text(
                          item.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZxType.caption.copyWith(color: t.text3),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.timeLabel(context),
                  style: ZxType.micro.copyWith(
                    color: t.text3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('ai-conversation-menu-${item.id}'),
                  tooltip: uiText(context, zh: '更多', en: 'More'),
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: t.text3,
                  ),
                  onSelected: (String action) =>
                      action == 'rename' ? _rename(item) : _delete(item),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'rename',
                          child: Text(uiText(context, zh: '重命名', en: 'Rename')),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(
                            uiText(context, zh: '删除', en: 'Delete'),
                            style: TextStyle(color: t.danger),
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

/// Asks for a new title; true once saved.
Future<bool> _renameConversation(
  BuildContext context,
  String id,
  String current,
) async {
  final String? title = await showDialog<String>(
    context: context,
    builder: (_) => _RenameChatDialog(initial: current),
  );
  final String trimmed = (title ?? '').trim();
  if (trimmed.isEmpty || trimmed == current) return false;
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await _writeIndex(
    prefs,
    _readIndex(prefs)
        .map(
          (_ConversationPreview row) =>
              row.id == id ? row.withTitle(trimmed) : row,
        )
        .toList(),
  );
  return true;
}

/// Confirms, then removes the chat from this device; true once removed.
Future<bool> _deleteConversation(
  BuildContext context,
  String id,
  String title,
) async {
  final bool confirmed = await zxConfirm(
    context,
    title: uiText(context, zh: '删除对话？', en: 'Delete chat?'),
    message: uiText(
      context,
      zh: '「$title」的聊天记录会从本机删除。',
      en: 'The messages in "$title" are removed from this device.',
    ),
    confirmLabel: uiText(context, zh: '删除', en: 'Delete'),
    cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
    danger: true,
  );
  if (!confirmed) return false;
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.remove('$_conversationKeyPrefix$id');
  await _writeIndex(
    prefs,
    _readIndex(
      prefs,
    ).where((_ConversationPreview row) => row.id != id).toList(),
  );
  return true;
}

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({
    super.key,
    this.conversationId,
    this.embedded = false,
    this.onChanged,
    this.onDeleted,
  });

  final String? conversationId;

  /// The right pane of [AiPage]'s wide layout rather than its own route.
  final bool embedded;

  /// After a turn is saved or the chat renamed, so a history beside it
  /// can refresh.
  final VoidCallback? onChanged;
  final VoidCallback? onDeleted;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final List<AiMessage> _messages = <AiMessage>[];
  late final String _conversationId;
  String _title = '';
  bool _sending = false;

  /// Set when the server answered 503: no AI provider is configured.
  bool _unavailable = false;

  /// Set while an answer is generating; [_stop] cancels it on the server.
  String? _activeRequestId;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId ?? _newId();
    _loadMessages();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final dynamic decoded = _decodeJsonList(
      prefs.getString('$_conversationKeyPrefix$_conversationId'),
    );
    final String title =
        _readIndex(prefs)
            .where((_ConversationPreview row) => row.id == _conversationId)
            .firstOrNull
            ?.title ??
        '';
    if (!mounted || decoded is! List) return;
    setState(() {
      _title = title;
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
    _scrollToBottom();
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
    final DateTime now = DateTime.now();
    final String title = renamed
        ? existing!.title
        : first.content.length > 24
        ? '${first.content.substring(0, 24)}…'
        : first.content;
    rows.insert(
      0,
      _ConversationPreview(
        id: _conversationId,
        // A renamed chat keeps the user's title.
        title: title,
        preview: _messages.isEmpty ? '' : _messages.last.content,
        updatedAt: '${now.month}/${now.day}',
        updatedAtMs: now.millisecondsSinceEpoch,
        renamed: renamed,
      ),
    );
    await _writeIndex(prefs, rows);
    if (mounted) setState(() => _title = title);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final bool hasChat = _messages.isNotEmpty;
    final String title = _title.isNotEmpty
        ? _title
        : uiText(context, zh: '新对话', en: 'New chat');
    final String subtitle = uiText(
      context,
      zh: '小电 · ${_messages.length} 条消息',
      en: 'Xiaodian · ${_messages.length} messages',
    );
    final List<Widget> actions = <Widget>[
      if (hasChat) ...<Widget>[
        ZxButton(
          key: const Key('ai-chat-rename'),
          label: uiText(context, zh: '重命名', en: 'Rename'),
          icon: Icons.edit_outlined,
          variant: ZxButtonVariant.secondary,
          small: true,
          onPressed: _renameThis,
        ),
        const SizedBox(width: 8),
        ZxButton(
          key: const Key('ai-chat-delete'),
          label: uiText(context, zh: '删除', en: 'Delete'),
          icon: Icons.delete_outline_rounded,
          variant: ZxButtonVariant.secondary,
          small: true,
          onPressed: _deleteThis,
        ),
      ],
    ];

    final Widget heading = Row(
      children: <Widget>[
        const _AiMark(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZxType.label.copyWith(color: t.text),
              ),
              Text(subtitle, style: ZxType.caption.copyWith(color: t.text3)),
            ],
          ),
        ),
      ],
    );

    final Widget body = Column(
      children: <Widget>[
        Expanded(
          child: !hasChat && !_sending
              ? _Welcome(onAsk: (String q) => _ask(q))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (BuildContext context, int index) {
                    final Widget child;
                    if (index == _messages.length) {
                      child = const _Thinking();
                    } else {
                      final AiMessage message = _messages[index];
                      child = message.role == 'user'
                          ? _UserBubble(content: message.content)
                          : _AnswerView(
                              message: message,
                              onReferenceTap: _openReference,
                              onRegenerate:
                                  index == _messages.length - 1 && !_sending
                                  ? _regenerate
                                  : null,
                            );
                    }
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: child,
                      ),
                    );
                  },
                ),
        ),
        _buildComposer(t),
      ],
    );

    if (widget.embedded) {
      return Column(
        children: <Widget>[
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(child: heading),
                ...actions,
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: uiText(context, zh: '返回', en: 'Back'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: heading,
        actions: <Widget>[
          if (hasChat)
            PopupMenuButton<String>(
              key: const Key('ai-chat-menu'),
              tooltip: uiText(context, zh: '更多', en: 'More'),
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (String action) =>
                  action == 'rename' ? _renameThis() : _deleteThis(),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'rename',
                  child: Text(uiText(context, zh: '重命名', en: 'Rename')),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(
                    uiText(context, zh: '删除', en: 'Delete'),
                    style: TextStyle(color: t.danger),
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ZxPaper(child: body),
    );
  }

  Widget _buildComposer(ZxTokens t) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_unavailable)
                  Padding(
                    key: const Key('ai-unavailable'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ZxInlineMessage(
                      message: uiText(
                        context,
                        zh: '服务器尚未配置 AI 服务，暂时无法提问',
                        en: 'The AI service is not set up on the server yet.',
                      ),
                      tone: ZxMessageTone.warning,
                      actionLabel: uiText(context, zh: '重试', en: 'Retry'),
                      onAction: () => setState(() => _unavailable = false),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: ZxRadius.cardAll,
                    border: Border.all(color: t.line),
                    boxShadow: t.shadow1,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: CallbackShortcuts(
                          // Enter sends, Shift + Enter breaks the line.
                          bindings: <ShortcutActivator, VoidCallback>{
                            const SingleActivator(
                              LogicalKeyboardKey.enter,
                            ): () {
                              if (!_sending) _send();
                            },
                          },
                          child: TextField(
                            key: const Key('ai-input'),
                            controller: _inputController,
                            focusNode: _inputFocus,
                            enabled: !_sending && !_unavailable,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            style: ZxType.body.copyWith(color: t.text),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              hintText: _unavailable
                                  ? uiText(
                                      context,
                                      zh: '暂时无法提问',
                                      en: 'Unavailable for now',
                                    )
                                  : uiText(
                                      context,
                                      zh: '继续提问，Enter 发送，Shift + Enter 换行',
                                      en: 'Ask away — Enter to send, Shift + Enter for a new line',
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: _sending
                            ? Tooltip(
                                message: uiText(context, zh: '停止', en: 'Stop'),
                                child: ZxButton(
                                  key: const Key('ai-stop'),
                                  label: uiText(context, zh: '停止', en: 'Stop'),
                                  icon: Icons.stop_rounded,
                                  variant: ZxButtonVariant.secondary,
                                  small: true,
                                  onPressed: _stop,
                                ),
                              )
                            : Tooltip(
                                message: uiText(context, zh: '发送', en: 'Send'),
                                child: Material(
                                  color: _unavailable
                                      ? t.primary.withValues(alpha: 0.4)
                                      : t.primary,
                                  borderRadius: ZxRadius.buttonAll,
                                  child: InkWell(
                                    key: const Key('ai-send'),
                                    borderRadius: ZxRadius.buttonAll,
                                    onTap: _unavailable ? null : _send,
                                    child: SizedBox(
                                      width: 42,
                                      height: 42,
                                      child: Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 20,
                                        color: t.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  uiText(
                    context,
                    zh: '内容由 AI 生成，请以学校通知为准',
                    en: 'AI-generated; the school’s own notices take precedence',
                  ),
                  style: ZxType.micro.copyWith(
                    color: t.text3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _renameThis() async {
    final String current = _title.isNotEmpty ? _title : '';
    if (await _renameConversation(context, _conversationId, current)) {
      await _loadMessages();
      widget.onChanged?.call();
    }
  }

  Future<void> _deleteThis() async {
    final String title = _title.isNotEmpty
        ? _title
        : uiText(context, zh: '新对话', en: 'New chat');
    if (!await _deleteConversation(context, _conversationId, title)) return;
    if (!mounted) return;
    if (widget.embedded) {
      widget.onDeleted?.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _send() => _ask(_inputController.text);

  /// Asks the last question again in place of the last answer.
  Future<void> _regenerate() async {
    final int lastUser = _messages.lastIndexWhere(
      (AiMessage m) => m.role == 'user',
    );
    if (lastUser < 0 || _sending) return;
    final String question = _messages[lastUser].content;
    setState(() => _messages.removeRange(lastUser, _messages.length));
    await _ask(question);
  }

  Future<void> _ask(String raw) async {
    final String text = raw.trim();
    if (text.isEmpty || _sending || _unavailable) return;
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
      if (mounted) {
        setState(
          () => _messages.add(
            AiMessage(
              role: 'assistant',
              content: response.answer,
              references: response.references,
            ),
          ),
        );
      }
      await _saveMessages();
    } catch (error) {
      // A stopped request fails with 409 by design; that is not an error.
      if (_activeRequestId != requestId) return;
      if (error is ApiException && error.statusCode == 503) {
        if (mounted) setState(() => _unavailable = true);
      } else if (mounted) {
        zxShowToast(
          context,
          uiText(
            context,
            zh: '暂时无法回复，请稍后再试',
            en: 'Unable to reply right now. Try again later.',
          ),
        );
      }
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
      if (mounted) {
        zxShowToast(
          context,
          uiText(
            context,
            zh: '停止请求未送达，回答可能仍在生成',
            en: 'Could not reach the server to stop the answer.',
          ),
        );
      }
    }
  }

  Future<void> _openReference(AiReference reference) async {
    if (reference.type != 'post' && reference.type != '帖子') {
      final Uri? uri = Uri.tryParse(reference.sourceUrl);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    final String postId = reference.targetId.trim();
    if (postId.isEmpty) return;
    final PostItem post = await AppRepositories.posts.fetchPostDetail(postId);
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PostDetailPage(post: post)),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

/// 小电's mark: the sparkle on a warm tile.
class _AiMark extends StatelessWidget {
  const _AiMark({this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.primarySoft,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: t.line),
      ),
      child: Icon(
        Icons.auto_awesome_outlined,
        size: size * 0.5,
        color: t.primary,
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onAsk});

  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final List<String> examples = <String>[
      uiText(context, zh: '图书馆期末周开放到几点？', en: 'Library hours during finals?'),
      uiText(
        context,
        zh: '南校区哪里可以打印？',
        en: 'Where can I print on south campus?',
      ),
      uiText(context, zh: '怎么申请缓考？', en: 'How do I defer an exam?'),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _AiMark(size: 52),
              const SizedBox(height: 14),
              Text(
                uiText(context, zh: '有什么可以帮你？', en: 'How can I help?'),
                style: ZxType.headline.copyWith(color: t.text),
              ),
              const SizedBox(height: 6),
              Text(
                uiText(
                  context,
                  zh: '小电会查找学校通知和社区帖子，并注明出处',
                  en: 'Xiaodian searches school notices and posts, and cites them.',
                ),
                textAlign: TextAlign.center,
                style: ZxType.body.copyWith(color: t.text2),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  for (final String q in examples)
                    ActionChip(label: Text(q), onPressed: () => onAsk(q)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18, left: 60),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[t.primary, t.primaryPressed],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: SelectableText(
            content,
            style: ZxType.body.copyWith(color: t.onPrimary),
          ),
        ),
      ),
    );
  }
}

class _AnswerView extends StatelessWidget {
  const _AnswerView({
    required this.message,
    required this.onReferenceTap,
    required this.onRegenerate,
  });

  final AiMessage message;
  final ValueChanged<AiReference> onReferenceTap;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _AiMark(size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SelectableText(
                  message.content,
                  style: ZxType.body.copyWith(color: t.text, height: 1.7),
                ),
                if (message.references.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.description_outlined,
                        size: 14,
                        color: t.text3,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        uiText(
                          context,
                          zh: '引用来源 · ${message.references.length}',
                          en: 'Sources · ${message.references.length}',
                        ),
                        style: ZxType.caption.copyWith(color: t.text3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < message.references.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: t.surface,
                        borderRadius: ZxRadius.buttonAll,
                        child: InkWell(
                          borderRadius: ZxRadius.buttonAll,
                          onTap: () => onReferenceTap(message.references[i]),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: ZxRadius.buttonAll,
                              border: Border.all(color: t.line),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: t.primarySoft,
                                    borderRadius: ZxRadius.badgeAll,
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: ZxType.micro.copyWith(
                                      color: t.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        message.references[i].title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: ZxType.label.copyWith(
                                          color: t.text,
                                        ),
                                      ),
                                      if (message.references[i].type
                                          .trim()
                                          .isNotEmpty)
                                        Text(
                                          localizedAiReferenceType(
                                            locale,
                                            message.references[i].type,
                                          ),
                                          style: ZxType.caption.copyWith(
                                            color: t.text3,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                  color: t.text3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: uiText(context, zh: '复制', en: 'Copy'),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.copy_rounded, size: 16, color: t.text3),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: message.content),
                        );
                        if (context.mounted) {
                          zxShowToast(
                            context,
                            uiText(context, zh: '已复制', en: 'Copied'),
                          );
                        }
                      },
                    ),
                    if (onRegenerate != null)
                      IconButton(
                        key: const Key('ai-regenerate'),
                        tooltip: uiText(context, zh: '重新回答', en: 'Regenerate'),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: t.text3,
                        ),
                        onPressed: onRegenerate,
                      ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        uiText(
                          context,
                          zh: '内容由 AI 生成，请以学校通知为准',
                          en: 'AI-generated; check official notices',
                        ),
                        textAlign: TextAlign.right,
                        style: ZxType.micro.copyWith(
                          color: t.text3,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: <Widget>[
          const _AiMark(size: 30),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: ZxRadius.pillAll,
              border: Border.all(color: t.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final double a in <double>[1, 0.65, 0.35])
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: a),
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  uiText(context, zh: '小电正在查找资料…', en: 'Looking things up…'),
                  style: ZxType.caption.copyWith(color: t.text2),
                ),
              ],
            ),
          ),
        ],
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
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: <Widget>[
        ZxButton(
          label: uiText(context, zh: '取消', en: 'Cancel'),
          variant: ZxButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ZxButton(
          label: uiText(context, zh: '保存', en: 'Save'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}

enum _Age { today, week, older }

class _ConversationPreview {
  const _ConversationPreview({
    required this.id,
    required this.title,
    required this.preview,
    required this.updatedAt,
    this.updatedAtMs = 0,
    this.renamed = false,
  });

  final String id;
  final String title;
  final String preview;

  /// `M/D`, as written before [updatedAtMs] existed.
  final String updatedAt;

  /// 0 for chats saved before this field; they group under 更早.
  final int updatedAtMs;

  /// Set once the user renames it; the title then stops following the
  /// first message.
  final bool renamed;

  DateTime? get _at =>
      updatedAtMs > 0 ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs) : null;

  _Age get age {
    final DateTime? at = _at;
    if (at == null) return _Age.older;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (!at.isBefore(today)) return _Age.today;
    final DateTime monday = today.subtract(Duration(days: now.weekday - 1));
    return at.isBefore(monday) ? _Age.older : _Age.week;
  }

  String timeLabel(BuildContext context) {
    final DateTime? at = _at;
    if (at == null) return updatedAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return switch (age) {
      _Age.today => '${two(at.hour)}:${two(at.minute)}',
      _Age.week => localizedWeekdayLabel(
        Localizations.localeOf(context),
        '一二三四五六日'[at.weekday - 1],
      ),
      _Age.older => '${two(at.month)}-${two(at.day)}',
    };
  }

  _ConversationPreview withTitle(String value) => _ConversationPreview(
    id: id,
    title: value,
    preview: preview,
    updatedAt: updatedAt,
    updatedAtMs: updatedAtMs,
    renamed: true,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'preview': preview,
    'updatedAt': updatedAt,
    if (updatedAtMs > 0) 'updatedAtMs': updatedAtMs,
    if (renamed) 'renamed': true,
  };

  factory _ConversationPreview.fromJson(Map<String, dynamic> json) =>
      _ConversationPreview(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        preview: json['preview']?.toString() ?? '',
        updatedAt: json['updatedAt']?.toString() ?? '',
        updatedAtMs: json['updatedAtMs'] is int
            ? json['updatedAtMs'] as int
            : 0,
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
