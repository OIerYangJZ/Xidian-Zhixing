import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/widgets/async_page_state.dart';
import '../../design_system/design_system.dart';
import '../../models/conversation_item.dart';
import 'chat_page.dart';
import 'messages_controller.dart';

/// 会话 (handoff W3): pending DM requests on top, then the conversations.
/// At [_splitMinWidth] and wider the open conversation sits beside the list.
class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  /// Below this width the chat opens as its own route; at or above it the
  /// list and the open conversation sit side by side.
  static const double _splitMinWidth = 900;

  String? _selectedId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      final MessagesState state = ref.read(messagesControllerProvider);
      if (!state.loading || state.conversations.isNotEmpty) {
        return Future<void>.value();
      }
      return ref.read(messagesControllerProvider.notifier).loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final MessagesState state = ref.watch(messagesControllerProvider);
    final MessagesController controller = ref.read(
      messagesControllerProvider.notifier,
    );
    final int unreadCount = state.conversations.fold<int>(
      0,
      (int sum, ConversationItem item) => sum + item.unreadCount,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(uiText(context, zh: '会话', en: 'Conversations')),
            const SizedBox(width: 8),
            ZxCountBadge(unreadCount),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: state.loading ? null : controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: uiText(context, zh: '刷新', en: 'Refresh'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ZxPaper(
        child: AsyncPageState(
          loading: state.loading,
          error: state.error,
          onRetry: controller.loadInitial,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < _splitMinWidth) {
                return _buildConversations(state, split: false);
              }
              final ConversationItem? selected = state.conversations
                  .where((ConversationItem item) => item.id == _selectedId)
                  .firstOrNull;
              return Row(
                children: <Widget>[
                  SizedBox(
                    width: 360,
                    child: _buildConversations(state, split: true),
                  ),
                  VerticalDivider(width: 1, color: t.line),
                  Expanded(
                    child: selected == null
                        ? ZxStatePanel(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: uiText(
                              context,
                              zh: '选择会话',
                              en: 'Select a conversation',
                            ),
                            message: uiText(
                              context,
                              zh: '从左侧打开一段对话',
                              en: 'Open a conversation from the list.',
                            ),
                          )
                        : _chatFor(selected, embedded: true),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openConversation(
    ConversationItem session, {
    required bool split,
  }) async {
    if (split) {
      setState(() => _selectedId = session.id);
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _chatFor(session)));
    if (!mounted) {
      return;
    }
    await ref.read(messagesControllerProvider.notifier).refresh();
  }

  Widget _chatFor(ConversationItem session, {bool embedded = false}) {
    final MessagesController controller = ref.read(
      messagesControllerProvider.notifier,
    );
    return ChatPage(
      // A new conversation in the same pane must not reuse the previous
      // one's state.
      key: ValueKey<String>(session.id),
      conversation: session,
      embedded: embedded,
      onConversationRead: () => controller.markConversationRead(session.id),
      onConversationRemoved: () {
        controller.removeConversation(session.id);
        if (mounted && _selectedId == session.id) {
          setState(() => _selectedId = null);
        }
      },
      onConversationFlagsChanged: ({bool? blockedByMe, bool? blockedByPeer}) {
        controller.updateConversationFlags(
          conversationId: session.id,
          blockedByMe: blockedByMe,
          blockedByPeer: blockedByPeer,
        );
      },
      onMessageSent: (String content) {
        controller.updateConversationPreview(
          conversationId: session.id,
          message: content,
        );
      },
    );
  }

  Future<bool> _confirmDelete(ConversationItem session) {
    return zxConfirm(
      context,
      title: uiText(context, zh: '删除会话', en: 'Delete conversation'),
      message: uiText(
        context,
        zh: '确定删除与「${session.name}」的会话吗？只从你的列表中移除。',
        en:
            'Delete your conversation with "${session.name}"? It is only '
            'removed from your list.',
      ),
      confirmLabel: uiText(context, zh: '删除', en: 'Delete'),
      cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
      danger: true,
    );
  }

  void _delete(ConversationItem session) {
    ref
        .read(messagesControllerProvider.notifier)
        .deleteConversation(session.id);
    if (_selectedId == session.id) {
      setState(() => _selectedId = null);
    }
  }

  Future<void> _showRowMenu(ConversationItem session, Offset position) async {
    final ZxTokens t = ZxTokens.of(context);
    final bool? delete = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: <PopupMenuEntry<bool>>[
        PopupMenuItem<bool>(
          value: true,
          child: Row(
            children: <Widget>[
              Icon(Icons.delete_outline_rounded, size: 18, color: t.danger),
              const SizedBox(width: 10),
              Text(
                uiText(context, zh: '删除会话', en: 'Delete conversation'),
                style: ZxType.body.copyWith(color: t.danger),
              ),
            ],
          ),
        ),
      ],
    );
    if (delete == true && mounted && await _confirmDelete(session)) {
      _delete(session);
    }
  }

  Widget _buildConversations(MessagesState state, {required bool split}) {
    final ZxTokens t = ZxTokens.of(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(messagesControllerProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
              children: <Widget>[
                if (state.conversations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: ZxStatePanel(
                      icon: Icons.forum_outlined,
                      title: uiText(
                        context,
                        zh: '还没有会话',
                        en: 'No conversations',
                      ),
                      message: uiText(
                        context,
                        zh: '在帖子或个人主页里向同学发起私信',
                        en: 'Message someone from a post or their profile.',
                      ),
                    ),
                  ),
                for (final ConversationItem session in state.conversations)
                  _conversationRow(session, split: split),
              ],
            ),
          ),
        ),
        if (state.conversations.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.line)),
            ),
            child: Text(
              split
                  ? uiText(
                      context,
                      zh: '右键会话可删除',
                      en: 'Right-click a conversation to delete it',
                    )
                  : uiText(
                      context,
                      zh: '向左滑可删除会话',
                      en: 'Swipe left to delete a conversation',
                    ),
              style: ZxType.caption.copyWith(color: t.text3),
            ),
          ),
      ],
    );
  }

  Widget _conversationRow(ConversationItem session, {required bool split}) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final bool selected = split && session.id == _selectedId;
    final bool unread = session.unreadCount > 0;
    final Widget row = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? t.primarySoft : Colors.transparent,
        borderRadius: ZxRadius.buttonAll,
        child: InkWell(
          borderRadius: ZxRadius.buttonAll,
          onTap: () => _openConversation(session, split: split),
          onSecondaryTapDown: (TapDownDetails details) =>
              _showRowMenu(session, details.globalPosition),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: <Widget>[
                ZxAvatar(
                  name: session.nameFor(locale),
                  imageUrl: session.avatarUrl,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    session.nameFor(locale),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ZxType.label.copyWith(color: t.text),
                                  ),
                                ),
                                if (session.blockedByMe) ...<Widget>[
                                  const SizedBox(width: 6),
                                  ZxBadge.blocked(
                                    uiText(context, zh: '已屏蔽', en: 'Blocked'),
                                  ),
                                ] else if (session.blockedByPeer) ...<Widget>[
                                  const SizedBox(width: 6),
                                  ZxBadge.blocked(
                                    uiText(
                                      context,
                                      zh: '对方已屏蔽',
                                      en: 'Blocked you',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            session.timeText,
                            style: ZxType.caption.copyWith(color: t.text3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              session.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ZxType.caption.copyWith(
                                fontSize: 13,
                                color: unread ? t.text : t.text2,
                                fontWeight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ZxCountBadge(session.unreadCount),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (split) return row;
    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(session),
      onDismissed: (_) => _delete(session),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: t.danger,
          borderRadius: ZxRadius.buttonAll,
        ),
        child: Icon(Icons.delete_outline_rounded, color: t.onDanger),
      ),
      child: row,
    );
  }
}
