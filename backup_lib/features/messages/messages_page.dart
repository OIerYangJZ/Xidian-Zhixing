import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/async_page_state.dart';
import '../../models/conversation_item.dart';
import '../../models/dm_request_item.dart';
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
    final int unreadCount = state.conversations.fold<int>(
      0,
      (int sum, ConversationItem item) => sum + item.unreadCount,
    );
    final int pendingCount = state.requests
        .where((DmRequestItem item) => item.status.toLowerCase() == 'pending')
        .length;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          TabBar(
            tabs: <Widget>[
              Tab(child: _buildTabLabel('私信申请', pendingCount)),
              Tab(child: _buildTabLabel('会话列表', unreadCount)),
            ],
          ),
          if (state.actionBusy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: AsyncPageState(
              loading: state.loading,
              error: state.error,
              onRetry: () =>
                  ref.read(messagesControllerProvider.notifier).loadInitial(),
              child: TabBarView(
                children: <Widget>[
                  _buildRequests(state),
                  _buildConversations(state),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequests(MessagesState state) {
    if (state.requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(messagesControllerProvider.notifier).refresh(),
        child: ListView(
          children: const <Widget>[
            SizedBox(height: 80),
            Center(child: Text('暂无私信申请。')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(messagesControllerProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.requests.length,
        itemBuilder: (BuildContext context, int index) {
          final DmRequestItem request = state.requests[index];
          final bool pending = request.status.toLowerCase() == 'pending';
          return Card(
            child: ListTile(
              leading: _buildAvatar(
                request.fromAvatarUrl,
                request.fromAlias,
              ),
              title: Text(request.fromAlias),
              subtitle: Text('${request.reason} · ${request.timeText}'),
              trailing: Wrap(
                spacing: 8,
                children: <Widget>[
                  if (pending) ...<Widget>[
                    FilledButton.tonal(
                      onPressed: state.actionBusy
                          ? null
                          : () => _handleRequest(request.id, false),
                      child: const Text('拒绝'),
                    ),
                    FilledButton(
                      onPressed: state.actionBusy
                          ? null
                          : () => _handleRequest(request.id, true),
                      child: const Text('同意'),
                    ),
                  ] else
                    Chip(
                      label: Text(request.statusLabel),
                      side: BorderSide(
                        color: request.status.toLowerCase() == 'accepted'
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
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
      onRefresh: () =>
          ref.read(messagesControllerProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.conversations.length,
        itemBuilder: (BuildContext context, int index) {
          final ConversationItem session = state.conversations[index];
          return Card(
            child: ListTile(
              leading: _buildAvatar(session.avatarUrl, session.name),
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
                  if (session.unreadCount > 0) ...<Widget>[
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
                      onConversationFlagsChanged: ({
                        bool? blockedByMe,
                        bool? blockedByPeer,
                      }) {
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
          );
        },
      ),
    );
  }

  Future<void> _handleRequest(String requestId, bool accept) async {
    final bool ok =
        await ref.read(messagesControllerProvider.notifier).handleRequest(
              requestId: requestId,
              accept: accept,
            );
    if (!mounted) {
      return;
    }
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? '已同意私信申请。' : '已拒绝私信申请。')),
      );
      return;
    }
    final String fallback =
        ref.read(messagesControllerProvider).error ?? '操作失败，请稍后重试';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(fallback)));
  }

  Widget _buildAvatar(String avatarUrl, String name) {
    final String resolved = AppConfig.resolveUrl(avatarUrl);
    final String fallback =
        name.trim().isEmpty ? '?' : name.trim().substring(0, 1);
    if (resolved.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: const Color(0xFFE5EAF3),
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

  Widget _buildTabLabel(String label, int count) {
    if (count <= 0) {
      return Text(label);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label),
        const SizedBox(width: 6),
        Badge(label: Text(count > 99 ? '99+' : '$count')),
      ],
    );
  }
}
