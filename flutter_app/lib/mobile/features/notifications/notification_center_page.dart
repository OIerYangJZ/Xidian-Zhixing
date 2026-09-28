import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xdu_treehole_web/models/notification_item.dart';

import '../../../design_system/design_system.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/utils/time_utils.dart';
import '../widgets/square_icon_button.dart';

/// 通知中心 (handoff N1): category chips, rows grouped by 今天 / 更早,
/// unread rows tinted with a dot, swipe left to mark one read.
class NotificationCenterPage extends ConsumerStatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  ConsumerState<NotificationCenterPage> createState() =>
      _NotificationCenterPageState();
}

class _NotificationCenterPageState
    extends ConsumerState<NotificationCenterPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsControllerProvider.notifier).loadInitial();
    });
  }

  Future<void> _refresh() async {
    await ref.read(notificationsControllerProvider.notifier).refresh();
  }

  static const Map<String, String> _categoryLabels = <String, String>{
    'comment': '评论',
    'reply': '回复',
    'like': '点赞',
    'favorite': '收藏',
    'repost': '转发',
    'mention': '@我',
    'report_result': '举报结果',
    'system': '系统',
  };

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final state = ref.watch(notificationsControllerProvider);
    final bool canPop = context.canPop();

    return Scaffold(
      backgroundColor: t.surface,
      appBar: AppBar(
        backgroundColor: t.surface,
        automaticallyImplyLeading: false,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: SquareIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: '返回',
                  onTap: () => context.pop(),
                ),
              )
            : null,
        leadingWidth: canPop ? 60 : null,
        titleSpacing: canPop ? 4 : 20,
        title: const Text('通知'),
        actions: [
          // Scoped to the selected category, like the list.
          if (state.unreadIn(state.category) > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ZxButton(
                key: const Key('mobile-notifications-read-all'),
                label: '全部已读',
                icon: Icons.done_all_rounded,
                small: true,
                variant: ZxButtonVariant.secondary,
                loading: state.actionBusy,
                onPressed: () => ref
                    .read(notificationsControllerProvider.notifier)
                    .markAllRead(),
              ),
            ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? ZxStatePanel(
              error: true,
              icon: Icons.error_outline_rounded,
              title: '通知加载失败',
              message: state.error!,
              actionLabel: '重试',
              onAction: _refresh,
            )
          : Column(
              children: [
                _buildCategoryBar(state),
                Divider(height: 1, color: t.line),
                Expanded(
                  child: state.visibleItems.isEmpty
                      ? ZxStatePanel(
                          icon: Icons.notifications_none_rounded,
                          title: state.category == null ? '暂无通知' : '这一类还没有通知',
                        )
                      : _buildList(state.visibleItems),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryBar(NotificationsState state) {
    final ZxTokens t = ZxTokens.of(context);
    final controller = ref.read(notificationsControllerProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          for (final String? category in <String?>[
            null,
            ...notificationCategories,
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                key: Key('mobile-notifications-${category ?? 'all'}'),
                label: category == null ? '全部' : _categoryLabels[category]!,
                count: state.unreadIn(category),
                selected: state.category == category,
                onTap: () => controller.selectCategory(category),
                tokens: t,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<NotificationItem> items) {
    final ZxTokens t = ZxTokens.of(context);
    final DateTime now = DateTime.now();
    bool isToday(NotificationItem item) {
      final DateTime? at = DateTime.tryParse(item.createdAt)?.toLocal();
      return at != null &&
          at.year == now.year &&
          at.month == now.month &&
          at.day == now.day;
    }

    final List<NotificationItem> today = items.where(isToday).toList();
    final List<NotificationItem> earlier = items
        .where((NotificationItem i) => !isToday(i))
        .toList();

    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        label,
        style: ZxType.caption.copyWith(
          color: t.text3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (today.isNotEmpty) ...[
            heading('今天'),
            for (final NotificationItem item in today) _row(item),
          ],
          if (earlier.isNotEmpty) ...[
            heading('更早'),
            for (final NotificationItem item in earlier) _row(item),
          ],
        ],
      ),
    );
  }

  Widget _row(NotificationItem item) {
    final ZxTokens t = ZxTokens.of(context);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final String actor = item.actorAlias.trim();
    final String title = item.displayTitleFor(Localizations.localeOf(context));
    final Color hue = _hueFor(t, item.category);
    final String content = item.content.trim();

    final Widget row = Material(
      color: item.isRead ? t.surface : t.primarySoft.withValues(alpha: 0.5),
      child: InkWell(
        onTap: () => _open(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 12,
                child: item.isRead
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 17),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: t.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color.lerp(hue, t.surface, 0.86),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(item.category), size: 20, color: hue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            actor.isEmpty ? title : '$actor $title',
                            style: ZxType.label.copyWith(
                              color: t.text,
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeText(item),
                          style: ZxType.caption.copyWith(color: t.text3),
                        ),
                      ],
                    ),
                    if (content.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: t.bgSunk,
                          borderRadius: ZxRadius.badgeAll,
                        ),
                        child: Text(
                          content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: ZxType.caption.copyWith(
                            fontSize: 13,
                            height: 1.45,
                            color: t.text2,
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
      ),
    );
    if (item.isRead) return row;
    return Dismissible(
      key: ValueKey<String>('notification-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: t.primary,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, color: t.onPrimary, size: 20),
            const SizedBox(height: 2),
            Text('标为已读', style: ZxType.caption.copyWith(color: t.onPrimary)),
          ],
        ),
      ),
      // The row stays in the list; only its state changes.
      confirmDismiss: (_) async {
        await controller.markRead(item.id);
        return false;
      },
      child: row,
    );
  }

  String _timeText(NotificationItem item) {
    final DateTime? parsed = DateTime.tryParse(item.createdAt);
    if (parsed != null) {
      return formatRelativeTime(parsed.isUtc ? parsed.toLocal() : parsed);
    }
    final String fallback = item.timeText.trim();
    return fallback.isEmpty ? '--' : fallback;
  }

  Color _hueFor(ZxTokens t, String category) => switch (category) {
    'comment' => t.info,
    'reply' => t.success,
    'like' => t.danger,
    'favorite' => t.accentInk,
    'repost' => t.info,
    'mention' => t.primary,
    'report_result' => t.success,
    _ => t.text2,
  };

  IconData _iconFor(String category) => switch (category) {
    'comment' => Icons.chat_bubble_outline_rounded,
    'reply' => Icons.reply_rounded,
    'like' => Icons.favorite_border_rounded,
    'favorite' => Icons.star_border_rounded,
    'repost' => Icons.repeat_rounded,
    'mention' => Icons.alternate_email_rounded,
    'report_result' => Icons.verified_user_outlined,
    _ => Icons.notifications_none_rounded,
  };

  void _open(NotificationItem item) {
    ref.read(notificationsControllerProvider.notifier).markRead(item.id);
    if (item.opensPost) {
      // A reply or comment points at the comment; open the post at it.
      final bool atComment =
          item.relatedType.trim().toLowerCase() == 'comment' &&
          item.relatedId.trim().isNotEmpty;
      context.push(
        Uri(
          path: '/post/${item.postId}',
          queryParameters: atComment
              ? <String, String>{'commentId': item.relatedId}
              : null,
        ).toString(),
      );
      return;
    }
    // 举报结果 goes to whoever owned the reported content (a reporter gets
    // none): it opens the post while there is one, else reads here.
    // An admin replied to or closed a 信箱 message.
    if (item.relatedType == 'feedback') {
      context.push('/profile/feedback');
      return;
    }
    if (item.content.trim().isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(item.displayTitle),
          content: SingleChildScrollView(child: Text(item.content)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }
}

/// A filter chip; the selected one is ink-filled with its count raised.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.tokens,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final ZxTokens tokens;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = tokens;
    final Color fg = selected ? t.bg : t.text;
    return Material(
      color: selected ? t.text : t.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? t.text : t.lineStrong),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: ZxType.label.copyWith(
                  fontSize: 13,
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 3),
                Text(
                  count > 99 ? '99+' : '$count',
                  style: ZxType.micro.copyWith(color: fg),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
