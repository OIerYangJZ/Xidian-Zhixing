import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';
import 'package:xdu_treehole_web/core/config/app_config.dart';
import 'package:xdu_treehole_web/models/conversation_item.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagesControllerProvider.notifier).loadInitial();
    });
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
      ),
      body: messagesState.loading
          ? const Center(child: CircularProgressIndicator(color: MobileTheme.primary))
          : _ConversationsTab(conversations: messagesState.conversations),
    );
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
