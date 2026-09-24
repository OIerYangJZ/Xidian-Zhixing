import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../core/widgets/async_page_state.dart';
import '../../design_system/design_system.dart';
import '../../models/notification_item.dart';
import '../../models/post_item.dart';
import '../../models/report_item.dart';
import '../../repositories/app_repositories.dart';
import '../me/report_detail_page.dart';
import 'notifications_controller.dart';

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
    Future<void>.microtask(() {
      final NotificationsState state = ref.read(
        notificationsControllerProvider,
      );
      if (!state.loading || state.items.isNotEmpty) {
        return Future<void>.value();
      }
      return ref.read(notificationsControllerProvider.notifier).loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final NotificationsState state = ref.watch(notificationsControllerProvider);
    final List<NotificationItem> items = state.visibleItems;
    final bool wide = MediaQuery.sizeOf(context).width >= 900;
    final NotificationsController controller = ref.read(
      notificationsControllerProvider.notifier,
    );
    final Widget markAll = ZxButton(
      key: const Key('notifications-read-all'),
      label: uiText(context, zh: '全部已读', en: 'Mark all read'),
      icon: Icons.done_all_rounded,
      variant: ZxButtonVariant.ghost,
      small: true,
      // Scoped to the selected category, like the list.
      onPressed: state.actionBusy || state.unreadIn(state.category) == 0
          ? null
          : controller.markAllRead,
    );
    final Widget list = RefreshIndicator(
      onRefresh: controller.refresh,
      child: _buildList(state, items, wide: wide),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '通知', en: 'Notifications')),
        actions: <Widget>[
          if (!wide) Center(child: markAll),
          const SizedBox(width: 8),
        ],
      ),
      body: ZxPaper(
        child: AsyncPageState(
          loading: state.loading,
          error: state.error,
          onRetry: controller.loadInitial,
          child: wide
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 220,
                            child: _CategoryList(
                              state: state,
                              labelFor: _categoryLabel,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Text(
                                      _categoryLabel(context, state.category) ==
                                              uiText(
                                                context,
                                                zh: '全部',
                                                en: 'All',
                                              )
                                          ? uiText(
                                              context,
                                              zh: '全部通知',
                                              en: 'All notifications',
                                            )
                                          : _categoryLabel(
                                              context,
                                              state.category,
                                            ),
                                      style: ZxType.title,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      uiText(
                                        context,
                                        zh: '${state.unreadIn(state.category)} 条未读',
                                        en: '${state.unreadIn(state.category)} unread',
                                      ),
                                      style: ZxType.caption.copyWith(
                                        color: ZxTokens.of(context).text3,
                                      ),
                                    ),
                                    const Spacer(),
                                    markAll,
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Expanded(child: list),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  children: <Widget>[
                    _CategoryBar(state: state, labelFor: _categoryLabel),
                    Expanded(child: list),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildList(
    NotificationsState state,
    List<NotificationItem> items, {
    required bool wide,
  }) {
    final ZxTokens t = ZxTokens.of(context);
    if (items.isEmpty) {
      return ListView(
        children: <Widget>[
          const SizedBox(height: 60),
          ZxStatePanel(
            icon: Icons.notifications_none_rounded,
            title: state.category == null
                ? uiText(context, zh: '暂时没有新的通知', en: 'No notifications yet')
                : uiText(
                    context,
                    zh: '这一类还没有通知',
                    en: 'Nothing in this category yet',
                  ),
          ),
        ],
      );
    }
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

    Widget group(String title, List<NotificationItem> rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Text(
            title,
            style: ZxType.caption.copyWith(
              color: t.text3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ZxCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < rows.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, color: t.line),
                _row(rows[i], wide: wide),
              ],
            ],
          ),
        ),
      ],
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 0 : 12, 0, wide ? 0 : 12, 40),
      children: <Widget>[
        if (today.isNotEmpty)
          group(uiText(context, zh: '今天', en: 'Today'), today),
        if (earlier.isNotEmpty)
          group(uiText(context, zh: '更早', en: 'Earlier'), earlier),
      ],
    );
  }

  Widget _row(NotificationItem item, {required bool wide}) {
    final ZxTokens t = ZxTokens.of(context);
    final NotificationsController controller = ref.read(
      notificationsControllerProvider.notifier,
    );
    final Locale locale = Localizations.localeOf(context);
    final String actor = item.actorAlias.trim();
    final Color hue = _hueFor(t, item.category);
    final Widget row = Material(
      color: item.isRead
          ? Colors.transparent
          : t.primarySoft.withValues(alpha: 0.55),
      child: InkWell(
        onTap: () => _openNotification(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 10,
                child: item.isRead
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: t.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color.lerp(hue, t.surface, 0.86),
                  borderRadius: ZxRadius.smallButtonAll,
                ),
                child: Icon(_iconForType(item.category), size: 18, color: hue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            actor.isEmpty
                                ? item.displayTitleFor(locale)
                                : '$actor ${item.displayTitleFor(locale)}',
                            style: ZxType.body.copyWith(
                              color: t.text,
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (wide && !item.isRead) ...<Widget>[
                          ZxButton(
                            label: uiText(context, zh: '标为已读', en: 'Mark read'),
                            variant: ZxButtonVariant.ghost,
                            small: true,
                            onPressed: () => controller.markRead(item.id),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          item.timeText,
                          style: ZxType.caption.copyWith(color: t.text3),
                        ),
                      ],
                    ),
                    if (item.content.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: t.bgSunk,
                          borderRadius: ZxRadius.badgeAll,
                        ),
                        child: Text(
                          item.content.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: ZxType.caption.copyWith(
                            color: t.text2,
                            fontSize: 13,
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
    if (wide || item.isRead) return row;
    // Narrow: swipe left to mark read; the row stays in the list.
    return Dismissible(
      key: ValueKey<String>('notification-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: t.success,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Text(
          uiText(context, zh: '标为已读', en: 'Mark read'),
          style: ZxType.label.copyWith(color: t.onPrimary),
        ),
      ),
      confirmDismiss: (_) async {
        await controller.markRead(item.id);
        return false;
      },
      child: row,
    );
  }

  Color _hueFor(ZxTokens t, String category) => switch (category) {
    'comment' => t.info,
    'reply' => t.primary,
    'like' => t.danger,
    'favorite' => t.accentInk,
    'report_result' => t.warning,
    _ => t.text2,
  };

  Future<void> _openNotification(NotificationItem item) async {
    await ref.read(notificationsControllerProvider.notifier).markRead(item.id);
    if (!mounted) {
      return;
    }
    if (item.opensPost) {
      await _openPost(item.postId);
      return;
    }
    if (item.relatedType == 'report' && item.relatedId.trim().isNotEmpty) {
      await _openReport(item.relatedId);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(item.displayTitle),
          content: SingleChildScrollView(child: Text(item.content)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(uiText(context, zh: '关闭', en: 'Close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPost(String postId) async {
    try {
      final PostItem post = await AppRepositories.posts.fetchPostDetail(postId);
      if (!mounted) {
        return;
      }
      await openPostDetailPage(context, post: post);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(
              context,
              zh: '打开帖子失败：$error',
              en: 'Could not open post: $error',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openReport(String reportId) async {
    try {
      final ReportItem detail = await AppRepositories.users.fetchMyReportDetail(
        reportId,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReportDetailPage(report: detail),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(
              context,
              zh: '打开举报详情失败：$error',
              en: 'Could not open report details: $error',
            ),
          ),
        ),
      );
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'comment':
        return Icons.comment_outlined;
      case 'reply':
        return Icons.reply_outlined;
      case 'like':
        return Icons.thumb_up_alt_outlined;
      case 'favorite':
        return Icons.bookmark_border_rounded;
      case 'report_result':
        return Icons.flag_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }

  String _categoryLabel(BuildContext context, String? category) {
    switch (category) {
      case null:
        return uiText(context, zh: '全部', en: 'All');
      case 'comment':
        return uiText(context, zh: '评论', en: 'Comments');
      case 'reply':
        return uiText(context, zh: '回复', en: 'Replies');
      case 'like':
        return uiText(context, zh: '点赞', en: 'Likes');
      case 'favorite':
        return uiText(context, zh: '收藏', en: 'Saves');
      case 'report_result':
        return uiText(context, zh: '举报结果', en: 'Reports');
      default:
        return uiText(context, zh: '系统', en: 'System');
    }
  }
}

/// Narrow widths: category chips with each category's unread count.
class _CategoryBar extends ConsumerWidget {
  const _CategoryBar({required this.state, required this.labelFor});

  final NotificationsState state;
  final String Function(BuildContext, String?) labelFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: <Widget>[
          for (final String? category in <String?>[
            null,
            ...notificationCategories,
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                showCheckmark: false,
                selected: state.category == category,
                onSelected: (_) => ref
                    .read(notificationsControllerProvider.notifier)
                    .selectCategory(category),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(labelFor(context, category)),
                    if (state.unreadIn(category) > 0) ...<Widget>[
                      const SizedBox(width: 6),
                      ZxCountBadge(state.unreadIn(category)),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Wide widths: the categories as a side list (handoff N2).
class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.state, required this.labelFor});

  final NotificationsState state;
  final String Function(BuildContext, String?) labelFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ZxTokens t = ZxTokens.of(context);
    return ZxCard(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final String? category in <String?>[
            null,
            ...notificationCategories,
          ])
            Material(
              color: state.category == category
                  ? t.primarySoft
                  : Colors.transparent,
              borderRadius: ZxRadius.buttonAll,
              child: InkWell(
                borderRadius: ZxRadius.buttonAll,
                onTap: () => ref
                    .read(notificationsControllerProvider.notifier)
                    .selectCategory(category),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          labelFor(context, category),
                          style: ZxType.body.copyWith(
                            color: state.category == category
                                ? t.primary
                                : t.text2,
                            fontWeight: state.category == category
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      ZxCountBadge(state.unreadIn(category)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
