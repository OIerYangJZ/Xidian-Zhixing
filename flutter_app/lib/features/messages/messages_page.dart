import 'package:flutter/material.dart';

import '../../core/widgets/app_surfaces.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/widgets/async_page_state.dart';
import '../../models/conversation_item.dart';
import 'chat_page.dart';
import 'messages_controller.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  String? _selectedId;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      final MessagesState state = ref.read(messagesControllerProvider);
      if (!state.loading ||
          state.requests.isNotEmpty ||
          state.conversations.isNotEmpty) {
        return Future<void>.value();
      }
      return ref.read(messagesControllerProvider.notifier).loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final MessagesState state = ref.watch(messagesControllerProvider);
    final int unreadCount = state.conversations.fold<int>(
      0,
      (int sum, ConversationItem item) => sum + item.unreadCount,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(uiText(context, zh: '会话', en: 'Conversations')),
            if (unreadCount > 0) ...[
              const SizedBox(width: 6),
              Badge(label: Text(unreadCount > 99 ? '99+' : '$unreadCount')),
            ],
          ],
        ),
        centerTitle: true,
      ),
      body: AppPageFrame(
        maxWidth: 1160,
        padding: EdgeInsets.zero,
        child: AsyncPageState(
          loading: state.loading,
          error: state.error,
          onRetry: () =>
              ref.read(messagesControllerProvider.notifier).loadInitial(),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < 900) return _buildConversations(state);
              final ConversationItem? selected = state.conversations
                  .where((ConversationItem item) => item.id == _selectedId)
                  .firstOrNull;
              return Row(
                children: <Widget>[
                  SizedBox(
                    width: 340,
                    child: _buildConversations(state, split: true),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: selected == null
                        ? AppStatePanel(
                            icon: Icons.chat_bubble_outline,
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

  Widget _buildConversations(MessagesState state, {bool split = false}) {
    if (state.conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(messagesControllerProvider.notifier).refresh(),
        child: ListView(
          children: <Widget>[
            const SizedBox(height: 80),
            Center(
              child: Text(
                uiText(context, zh: '暂无会话。', en: 'No conversations.'),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(messagesControllerProvider.notifier).refresh(),
      child: ListView.separated(
        separatorBuilder: (_, __) => const Divider(height: 1),
        padding: EdgeInsets.zero,
        itemCount: state.conversations.length,
        itemBuilder: (BuildContext context, int index) {
          final ConversationItem session = state.conversations[index];
          return Dismissible(
            key: Key(session.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(
                    uiText(context, zh: '删除会话', en: 'Delete conversation'),
                  ),
                  content: Text(
                    uiText(
                      context,
                      zh: '确定删除与 "${session.name}" 的会话吗？',
                      en: 'Delete your conversation with "${session.name}"?',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(uiText(context, zh: '取消', en: 'Cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        uiText(context, zh: '删除', en: 'Delete'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (_) {
              ref
                  .read(messagesControllerProvider.notifier)
                  .deleteConversation(session.id);
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: GestureDetector(
                  onTap: () => _openConversation(session, split: split),
                  child: _buildAvatar(session.avatarUrl, session.name),
                ),
                title: Row(
                  children: <Widget>[
                    Expanded(child: Text(session.name)),
                    if (session.blockedByMe)
                      Chip(
                        label: Text(uiText(context, zh: '已屏蔽', en: 'Blocked')),
                        visualDensity: VisualDensity.compact,
                      )
                    else if (session.blockedByPeer)
                      Chip(
                        label: Text(
                          uiText(context, zh: '对方已屏蔽', en: 'Blocked by user'),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                subtitle: Text(
                  session.lastMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(session.timeText),
                    if (session.unreadCount > 0) ...[
                      const SizedBox(height: 6),
                      Badge(
                        label: Text(
                          session.unreadCount > 99
                              ? '99+'
                              : '${session.unreadCount}',
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () => _openConversation(session, split: split),
              ),
            ),
          );
        },
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
    if (mounted) await ref.read(messagesControllerProvider.notifier).refresh();
  }

  Widget _chatFor(ConversationItem session, {bool embedded = false}) {
    return ChatPage(
      key: ValueKey(session.id),
      conversation: session,
      embedded: embedded,
      peerUserId: session.peerUserId.isEmpty ? null : session.peerUserId,
      onConversationRead: () => ref
          .read(messagesControllerProvider.notifier)
          .markConversationRead(session.id),
      onConversationRemoved: () {
        ref
            .read(messagesControllerProvider.notifier)
            .removeConversation(session.id);
        if (mounted) setState(() => _selectedId = null);
      },
      onConversationFlagsChanged: ({bool? blockedByMe, bool? blockedByPeer}) =>
          ref
              .read(messagesControllerProvider.notifier)
              .updateConversationFlags(
                conversationId: session.id,
                blockedByMe: blockedByMe,
                blockedByPeer: blockedByPeer,
              ),
      onMessageSent: (String content) => ref
          .read(messagesControllerProvider.notifier)
          .updateConversationPreview(
            conversationId: session.id,
            message: content,
          ),
    );
  }

  Widget _buildAvatar(String avatarUrl, String name) {
    final String resolved = AppConfig.resolveUrl(avatarUrl);
    final String fallback = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1);
    if (resolved.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        child: ClipOval(
          child: Image.network(
            resolved,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Text(fallback),
          ),
        ),
      );
    }
    return CircleAvatar(child: Text(fallback));
  }
}
