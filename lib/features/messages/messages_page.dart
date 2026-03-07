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
    Future<void>.microtask(
      () => ref.read(messagesControllerProvider.notifier).loadInitial(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MessagesState state = ref.watch(messagesControllerProvider);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: '私信申请'),
              Tab(text: '会话列表'),
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
      return const Center(child: Text('暂无私信申请。'));
    }
    return ListView.builder(
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
    );
  }

  Widget _buildConversations(MessagesState state) {
    if (state.conversations.isEmpty) {
      return const Center(child: Text('暂无会话。'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.conversations.length,
      itemBuilder: (BuildContext context, int index) {
        final ConversationItem session = state.conversations[index];
        return Card(
          child: ListTile(
            leading: _buildAvatar(session.avatarUrl, session.name),
            title: Text(session.name),
            subtitle: Text(session.lastMessage),
            trailing: Text(session.timeText),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatPage(
                    conversation: session,
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
            },
          ),
        );
      },
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
    final String resolved = _resolveAvatarUrl(avatarUrl);
    if (resolved.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(resolved));
    }
    final String fallback =
        name.trim().isEmpty ? '?' : name.trim().substring(0, 1);
    return CircleAvatar(child: Text(fallback));
  }

  String _resolveAvatarUrl(String avatarUrl) {
    final String trimmed = avatarUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      final Uri base = Uri.parse(AppConfig.apiBaseUrl);
      return '${base.scheme}://${base.authority}$trimmed';
    }
    return '';
  }
}
