import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';
import 'package:xdu_treehole_web/core/config/app_config.dart';
import 'package:xdu_treehole_web/models/conversation_item.dart';
import 'package:xdu_treehole_web/models/dm_request_item.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagesControllerProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(messagesControllerProvider);
    final pendingCount =
        messagesState.requests.where((r) => r.status == 'pending').length;

    return Scaffold(
      backgroundColor: MobileTheme.background,
      appBar: AppBar(
        backgroundColor: MobileTheme.surface,
        title: const Text(
          '消息中心',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '私信申请${pendingCount > 0 ? ' ($pendingCount)' : ''}'),
            const Tab(text: '会话列表'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RequestsTab(
              requests: messagesState.requests,
              actionBusy: messagesState.actionBusy),
          _ConversationsTab(conversations: messagesState.conversations),
        ],
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  final List<DmRequestItem> requests;
  final bool actionBusy;

  const _RequestsTab({
    required this.requests,
    required this.actionBusy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64, color: MobileTheme.textTertiary),
            SizedBox(height: 16),
            Text(
              '暂无私信申请',
              style: TextStyle(color: MobileTheme.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(messagesControllerProvider.notifier).refresh(),
      child: ListView.separated(
        itemCount: requests.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final request = requests[index];
          return _RequestTile(request: request, actionBusy: actionBusy);
        },
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final DmRequestItem request;
  final bool actionBusy;

  const _RequestTile({
    required this.request,
    required this.actionBusy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = request.status == 'pending';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: MobileTheme.primary.withValues(alpha: 0.1),
        backgroundImage: request.fromAvatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(
                request.fromAvatarUrl.startsWith('http')
                    ? request.fromAvatarUrl
                    : AppConfig.resolveUrl(request.fromAvatarUrl),
              )
            : null,
        child: request.fromAvatarUrl.isEmpty
            ? const Icon(Icons.person, color: MobileTheme.primary, size: 22)
            : null,
      ),
      title: Text(
        request.fromAlias,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (request.reason.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              request.reason,
              style: const TextStyle(
                  color: MobileTheme.textSecondary, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 2),
          Text(
            request.timeText,
            style:
                const TextStyle(color: MobileTheme.textTertiary, fontSize: 12),
          ),
        ],
      ),
      trailing: isPending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: actionBusy
                      ? null
                      : () => _handleRequest(context, ref, true),
                  style: TextButton.styleFrom(
                    foregroundColor: MobileTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('同意', style: TextStyle(fontSize: 14)),
                ),
                TextButton(
                  onPressed: actionBusy
                      ? null
                      : () => _handleRequest(context, ref, false),
                  style: TextButton.styleFrom(
                    foregroundColor: MobileTheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('拒绝', style: TextStyle(fontSize: 14)),
                ),
              ],
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: request.status == 'approved'
                    ? MobileTheme.success.withValues(alpha: 0.1)
                    : MobileTheme.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                request.statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: request.status == 'approved'
                      ? MobileTheme.success
                      : MobileTheme.textTertiary,
                ),
              ),
            ),
    );
  }

  Future<void> _handleRequest(
      BuildContext context, WidgetRef ref, bool accept) async {
    final success =
        await ref.read(messagesControllerProvider.notifier).handleRequest(
              requestId: request.id,
              accept: accept,
            );

    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? '已同意' : '已拒绝'),
          backgroundColor: accept ? MobileTheme.success : null,
        ),
      );
    }
  }
}

class _ConversationsTab extends ConsumerWidget {
  final List<ConversationItem> conversations;

  const _ConversationsTab({required this.conversations});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (conversations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: MobileTheme.textTertiary),
            SizedBox(height: 16),
            Text(
              '暂无会话',
              style: TextStyle(color: MobileTheme.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(messagesControllerProvider.notifier).refresh(),
      child: ListView.separated(
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          return _ConversationTile(conversation: conversation);
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationItem conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: MobileTheme.primary.withValues(alpha: 0.1),
        backgroundImage: conversation.avatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(
                conversation.avatarUrl.startsWith('http')
                    ? conversation.avatarUrl
                    : AppConfig.resolveUrl(conversation.avatarUrl),
              )
            : null,
        child: conversation.avatarUrl.isEmpty
            ? const Icon(Icons.person, color: MobileTheme.primary, size: 22)
            : null,
      ),
      title: Text(
        conversation.name,
        style: TextStyle(
          fontWeight:
              conversation.hasUnread ? FontWeight.w700 : FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        conversation.lastMessage,
        style: TextStyle(
          color: conversation.hasUnread
              ? MobileTheme.textPrimary
              : MobileTheme.textSecondary,
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            conversation.timeText,
            style: const TextStyle(
              color: MobileTheme.textTertiary,
              fontSize: 12,
            ),
          ),
          if (conversation.hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: MobileTheme.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                conversation.unreadCount > 99
                    ? '99+'
                    : conversation.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        context.push(
          '/chat/${conversation.id}?name=${Uri.encodeComponent(conversation.name)}&avatar=${Uri.encodeComponent(conversation.avatarUrl)}',
        );
      },
    );
  }
}
