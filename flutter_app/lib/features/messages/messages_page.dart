import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/async_page_state.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/conversation_item.dart';
import 'chat_page.dart';
import 'messages_controller.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
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

    return Scaffold(
      appBar: const AppPageTopActions(leading: BackButton()),
      body: AsyncPageState(
        loading: state.loading,
        error: state.error,
        onRetry: () =>
            ref.read(messagesControllerProvider.notifier).loadInitial(),
        child: _buildConversations(state),
      ),
    );
  }

  Widget _buildConversations(MessagesState state) {
    if (state.conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(messagesControllerProvider.notifier).refresh(),
        child: ListView(
          children: const <Widget>[
            SizedBox(height: 80),
            Center(child: Text('暂无会话。')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(messagesControllerProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                  title: const Text('删除会话'),
                  content: Text('确定删除与 "${session.name}" 的会话吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        '删除',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
              color: Theme.of(context).colorScheme.error,
              child: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: ListTile(
                leading: GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatPage(
                          conversation: session,
                          onConversationRead: () {
                            ref
                                .read(messagesControllerProvider.notifier)
                                .markConversationRead(session.id);
                          },
                          onConversationRemoved: () {
                            ref
                                .read(messagesControllerProvider.notifier)
                                .removeConversation(session.id);
                          },
                          onConversationFlagsChanged:
                              ({bool? blockedByMe, bool? blockedByPeer}) {
                                ref
                                    .read(messagesControllerProvider.notifier)
                                    .updateConversationFlags(
                                      conversationId: session.id,
                                      blockedByMe: blockedByMe,
                                      blockedByPeer: blockedByPeer,
                                    );
                              },
                          onMessageSent: (String content) {
                            ref
                                .read(messagesControllerProvider.notifier)
                                .updateConversationPreview(
                                  conversationId: session.id,
                                  message: content,
                                );
                          },
                        ),
                      ),
                    );
                    if (!mounted) {
                      return;
                    }
                    await ref
                        .read(messagesControllerProvider.notifier)
                        .refresh();
                  },
                  child: _buildAvatar(session.avatarUrl, session.name),
                ),
                title: Row(
                  children: <Widget>[
                    Expanded(child: Text(session.name)),
                    if (session.blockedByMe)
                      const Chip(
                        label: Text('已屏蔽'),
                        visualDensity: VisualDensity.compact,
                      )
                    else if (session.blockedByPeer)
                      const Chip(
                        label: Text('对方已屏蔽'),
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
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatPage(
                        conversation: session,
                        onConversationRead: () {
                          ref
                              .read(messagesControllerProvider.notifier)
                              .markConversationRead(session.id);
                        },
                        onConversationRemoved: () {
                          ref
                              .read(messagesControllerProvider.notifier)
                              .removeConversation(session.id);
                        },
                        onConversationFlagsChanged:
                            ({bool? blockedByMe, bool? blockedByPeer}) {
                              ref
                                  .read(messagesControllerProvider.notifier)
                                  .updateConversationFlags(
                                    conversationId: session.id,
                                    blockedByMe: blockedByMe,
                                    blockedByPeer: blockedByPeer,
                                  );
                            },
                        onMessageSent: (String content) {
                          ref
                              .read(messagesControllerProvider.notifier)
                              .updateConversationPreview(
                                conversationId: session.id,
                                message: content,
                              );
                        },
                      ),
                    ),
                  );
                  if (!mounted) {
                    return;
                  }
                  await ref.read(messagesControllerProvider.notifier).refresh();
                },
              ),
            ),
          );
        },
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
