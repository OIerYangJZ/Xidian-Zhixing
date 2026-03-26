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
  late final TabController _tabController;

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

    return Scaffold(
      backgroundColor: MobileTheme.background,
      appBar: AppBar(
        backgroundColor: MobileTheme.surface,
        title: const Text(
          '消息',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: MobileTheme.primary,
          unselectedLabelColor: MobileTheme.textSecondary,
          indicatorColor: MobileTheme.primary,
          indicatorWeight: 2,
          tabs: [
            const Tab(text: '会话'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('私信申请'),
                  if (messagesState.requests
                      .any((r) => r.status == 'pending')) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: MobileTheme.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${messagesState.requests.where((r) => r.status == 'pending').length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ConversationsTab(
            conversations: messagesState.conversations,
            loading: messagesState.loading,
          ),
          _DmRequestsTab(
            requests: messagesState.requests,
            loading: messagesState.loading,
            actionBusy: messagesState.actionBusy,
          ),
        ],
      ),
    );
  }
}

class _ConversationsTab extends ConsumerWidget {
  final List<ConversationItem> conversations;
  final bool loading;

  const _ConversationsTab({
    required this.conversations,
    required this.loading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: MobileTheme.primary),
      );
    }
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
            SizedBox(height: 8),
            Text(
              '点击他人帖子或评论中的头像，即可发起私信',
              style: TextStyle(color: MobileTheme.textTertiary, fontSize: 13),
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
          return Dismissible(
            key: Key(conversation.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('删除会话'),
                  content:
                      Text('确定删除与 "${conversation.name}" 的会话吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('删除',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (_) {
              ref
                  .read(messagesControllerProvider.notifier)
                  .deleteConversation(conversation.id);
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: _ConversationTile(conversation: conversation),
          );
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
      leading: GestureDetector(
        onTap: () => context.push('/user/${conversation.peerUserId}'),
        child: CircleAvatar(
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
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.name,
              style: TextStyle(
                fontWeight:
                    conversation.hasUnread ? FontWeight.w700 : FontWeight.w600,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conversation.isBlocked) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: MobileTheme.textTertiary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                '已屏蔽',
                style: TextStyle(
                  fontSize: 10,
                  color: MobileTheme.textTertiary,
                ),
              ),
            ),
          ],
        ],
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

class _DmRequestsTab extends ConsumerWidget {
  final List<DmRequestItem> requests;
  final bool loading;
  final bool actionBusy;

  const _DmRequestsTab({
    required this.requests,
    required this.loading,
    required this.actionBusy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: MobileTheme.primary),
      );
    }
    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: MobileTheme.textTertiary),
            SizedBox(height: 16),
            Text(
              '暂无私信申请',
              style: TextStyle(color: MobileTheme.textSecondary, fontSize: 15),
            ),
            SizedBox(height: 8),
            Text(
              '收到的私信申请会显示在这里',
              style: TextStyle(color: MobileTheme.textTertiary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(messagesControllerProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 0),
        itemBuilder: (context, index) {
          final request = requests[index];
          return _DmRequestCard(
            request: request,
            actionBusy: actionBusy,
          );
        },
      ),
    );
  }
}

class _DmRequestCard extends ConsumerWidget {
  final DmRequestItem request;
  final bool actionBusy;

  const _DmRequestCard({
    required this.request,
    required this.actionBusy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = request.status == 'pending';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MobileTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: MobileTheme.primary.withValues(alpha: 0.1),
                backgroundImage: request.fromAvatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(
                        request.fromAvatarUrl.startsWith('http')
                            ? request.fromAvatarUrl
                            : AppConfig.resolveUrl(request.fromAvatarUrl),
                      )
                    : null,
                child: request.fromAvatarUrl.isEmpty
                    ? const Icon(Icons.person,
                        color: MobileTheme.primary, size: 20)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.fromAlias,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.timeText,
                      style: const TextStyle(
                        color: MobileTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPending)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: request.status == 'accepted'
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: request.status == 'accepted'
                          ? Colors.green
                          : MobileTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          if (request.reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MobileTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request.reason,
                style: const TextStyle(
                  fontSize: 13,
                  color: MobileTheme.textSecondary,
                ),
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: actionBusy
                        ? null
                        : () => ref
                            .read(messagesControllerProvider.notifier)
                            .handleRequest(requestId: request.id, accept: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MobileTheme.textSecondary,
                      side: const BorderSide(color: MobileTheme.divider),
                    ),
                    child: const Text('拒绝'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: actionBusy
                        ? null
                        : () => ref
                            .read(messagesControllerProvider.notifier)
                            .handleRequest(requestId: request.id, accept: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MobileTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('同意'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
