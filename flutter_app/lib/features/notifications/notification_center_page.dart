import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/async_page_state.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '通知中心', en: 'Notifications')),
        actions: <Widget>[
          IconButton(
            // Scoped to the selected category, like the list.
            onPressed: state.actionBusy || state.unreadIn(state.category) == 0
                ? null
                : () => ref
                      .read(notificationsControllerProvider.notifier)
                      .markAllRead(),
            icon: const Icon(Icons.done_all_outlined),
            tooltip: uiText(context, zh: '全部已读', en: 'Mark all as read'),
          ),
          IconButton(
            onPressed: state.loading
                ? null
                : () => ref
                      .read(notificationsControllerProvider.notifier)
                      .refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: uiText(context, zh: '刷新', en: 'Refresh'),
          ),
        ],
      ),
      body: AsyncPageState(
        loading: state.loading,
        error: state.error,
        onRetry: () =>
            ref.read(notificationsControllerProvider.notifier).loadInitial(),
        child: Column(
          children: <Widget>[
            _CategoryBar(state: state, labelFor: _categoryLabel),
            Expanded(child: _buildList(state, items)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(NotificationsState state, List<NotificationItem> items) {
    return items.isEmpty
            ? ListView(
                children: <Widget>[
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      state.category == null
                          ? uiText(
                              context,
                              zh: '暂时没有新的通知。',
                              en: 'No new notifications.',
                            )
                          : uiText(
                              context,
                              zh: '这一类还没有通知。',
                              en: 'Nothing in this category yet.',
                            ),
                    ),
                  ),
                ],
              )
            : RefreshIndicator(
                onRefresh: () => ref
                    .read(notificationsControllerProvider.notifier)
                    .refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (BuildContext context, int index) {
                    final NotificationItem item = items[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openNotification(item),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: item.isRead
                              ? Theme.of(context).colorScheme.surface
                              : Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: item.isRead
                                ? Theme.of(context).dividerColor
                                : Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            CircleAvatar(
                              backgroundColor: _badgeColor(item.type),
                              foregroundColor: Colors.white,
                              child: Icon(_iconForType(item.type), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          item.displayTitle,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (!item.isRead)
                                        const Badge(
                                          backgroundColor: Color(0xFFDC2626),
                                          smallSize: 9,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.content,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.72),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        _labelForType(context, item.type),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: SharedColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        item.timeText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.58),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.38),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: items.length,
                ),
              );
  }

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
      case 'system_announcement':
      default:
        return Icons.campaign_outlined;
    }
  }

  Color _badgeColor(String type) {
    switch (type) {
      case 'comment':
        return SharedColors.primary;
      case 'reply':
        return SharedColors.success;
      case 'like':
        return SharedColors.danger;
      case 'favorite':
        return SharedColors.warning;
      case 'report_result':
        return SharedColors.deep;
      case 'system_announcement':
      default:
        return SharedColors.textSecondary;
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

  String _labelForType(BuildContext context, String type) {
    switch (type) {
      case 'comment':
        return uiText(context, zh: '评论通知', en: 'Comment');
      case 'reply':
        return uiText(context, zh: '回复通知', en: 'Reply');
      case 'like':
        return uiText(context, zh: '点赞通知', en: 'Like');
      case 'favorite':
        return uiText(context, zh: '收藏通知', en: 'Favorite');
      case 'report_result':
        return uiText(context, zh: '举报结果', en: 'Report result');
      case 'system_announcement':
      default:
        return uiText(context, zh: '系统公告', en: 'System announcement');
    }
  }
}

/// Category chips with each category's unread count.
class _CategoryBar extends ConsumerWidget {
  const _CategoryBar({required this.state, required this.labelFor});

  final NotificationsState state;
  final String Function(BuildContext, String?) labelFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: <Widget>[
          for (final String? category in <String?>[
            null,
            ...notificationCategories,
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
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
                      Badge(
                        label: Text(
                          state.unreadIn(category) > 99
                              ? '99+'
                              : '${state.unreadIn(category)}',
                        ),
                      ),
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
