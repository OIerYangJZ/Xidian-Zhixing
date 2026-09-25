import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/mobile_providers.dart';
import '../shell/mobile_shell.dart';
import 'package:xdu_treehole_web/design_system/design_system.dart';
import 'package:xdu_treehole_web/features/messages/messages_controller.dart';
import 'package:xdu_treehole_web/models/conversation_item.dart';
import 'package:xdu_treehole_web/models/notification_item.dart';

/// 消息 (handoff A3): 通知 / 评论回复 / 赞与收藏 with their counts, then the
/// conversations. There are no message requests: a first message goes
/// straight into a conversation.
class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  final _scrollController = ScrollController();
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagesControllerProvider.notifier).loadInitial();
      ref.read(notificationsControllerProvider.notifier).loadInitial();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final delta = _scrollController.position.pixels - _lastScrollOffset;
    if (delta > 1) {
      BottomNavVisibilityNotifier.instance.hide();
    } else if (delta < -1) {
      BottomNavVisibilityNotifier.instance.show();
    }
    _lastScrollOffset = _scrollController.position.pixels;
  }

  Future<void> _refresh() async {
    await Future.wait(<Future<void>>[
      ref.read(messagesControllerProvider.notifier).refresh(),
      ref.read(notificationsControllerProvider.notifier).refresh(),
    ]);
  }

  void _openNotifications(String? category) {
    ref.read(notificationsControllerProvider.notifier).selectCategory(category);
    context.push('/notifications');
  }

  Future<bool> _confirmDelete(ConversationItem c) => zxConfirm(
    context,
    title: '删除会话',
    message: '确定删除与「${c.name}」的会话吗？只从你的列表中移除。',
    confirmLabel: '删除',
    cancelLabel: '取消',
    danger: true,
  );

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final MessagesState state = ref.watch(messagesControllerProvider);
    final notifications = ref.watch(notificationsControllerProvider);
    final int commentUnread = notifications.items
        .where(
          (NotificationItem n) =>
              !n.isRead && (n.category == 'comment' || n.category == 'reply'),
        )
        .length;
    final int likeUnread = notifications.items
        .where(
          (NotificationItem n) =>
              !n.isRead && (n.category == 'like' || n.category == 'favorite'),
        )
        .length;

    return Scaffold(
      backgroundColor: t.surface,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 320,
            child: ZxHeroWash(child: const SizedBox.expand()),
          ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: t.primary,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '消息',
                            style: ZxType.headline.copyWith(color: t.text),
                          ),
                        ),
                        IconButton(
                          tooltip: '刷新',
                          icon: Icon(Icons.refresh_rounded, color: t.text2),
                          onPressed: _refresh,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        _Entry(
                          key: const Key('mobile-messages-notifications'),
                          icon: Icons.notifications_none_rounded,
                          hue: t.primary,
                          label: '通知',
                          count: notifications.unreadCount,
                          onTap: () => _openNotifications(null),
                        ),
                        const SizedBox(width: 10),
                        _Entry(
                          key: const Key('mobile-messages-comments'),
                          icon: Icons.chat_bubble_outline_rounded,
                          hue: t.info,
                          label: '评论回复',
                          count: commentUnread,
                          onTap: () => _openNotifications('comment'),
                        ),
                        const SizedBox(width: 10),
                        _Entry(
                          key: const Key('mobile-messages-likes'),
                          icon: Icons.favorite_border_rounded,
                          hue: t.danger,
                          label: '赞与收藏',
                          count: likeUnread,
                          onTap: () => _openNotifications('like'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height * 0.6,
                    ),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(ZxRadius.sheet),
                      ),
                      border: Border(top: BorderSide(color: t.line)),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.loading && state.conversations.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.conversations.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: ZxStatePanel(
                              icon: Icons.forum_outlined,
                              title: '还没有会话',
                              message: '在帖子或个人主页里向同学发起私信',
                            ),
                          ),
                        for (final ConversationItem c in state.conversations)
                          Dismissible(
                            key: Key(c.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDelete(c),
                            onDismissed: (_) => ref
                                .read(messagesControllerProvider.notifier)
                                .deleteConversation(c.id),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: t.danger,
                                borderRadius: ZxRadius.buttonAll,
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: t.onDanger,
                              ),
                            ),
                            child: _ConversationRow(conversation: c),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    super.key,
    required this.icon,
    required this.hue,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final Color hue;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Expanded(
      child: ZxCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color.lerp(hue, t.surface, 0.86),
                    borderRadius: ZxRadius.buttonAll,
                  ),
                  child: Icon(icon, size: 20, color: hue),
                ),
                if (count > 0)
                  Positioned(right: -10, top: -6, child: ZxCountBadge(count)),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: ZxType.label.copyWith(color: t.text)),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation});

  final ConversationItem conversation;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final ConversationItem c = conversation;
    final bool unread = c.unreadCount > 0;
    return InkWell(
      borderRadius: ZxRadius.buttonAll,
      onTap: () => context.push(
        '/chat/${c.id}?name=${Uri.encodeComponent(c.name)}&avatar=${Uri.encodeComponent(c.avatarUrl)}&userId=${Uri.encodeComponent(c.peerUserId)}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Row(
          children: [
            ZxAvatar(
              name: c.nameFor(locale),
              imageUrl: c.avatarUrl,
              size: 48,
              onTap: c.peerUserId.isEmpty
                  ? null
                  : () => context.push('/user/${c.peerUserId}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.nameFor(locale),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ZxType.label.copyWith(color: t.text),
                              ),
                            ),
                            if (c.blockedByMe) ...[
                              const SizedBox(width: 6),
                              const ZxBadge.blocked('已屏蔽'),
                            ] else if (c.blockedByPeer) ...[
                              const SizedBox(width: 6),
                              const ZxBadge.blocked('对方已屏蔽'),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        c.timeText,
                        style: ZxType.caption.copyWith(color: t.text3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.lastMessage,
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
                      ZxCountBadge(c.unreadCount),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
