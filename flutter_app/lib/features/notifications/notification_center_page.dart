import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/async_page_state.dart';
import '../../core/widgets/app_surfaces.dart';
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
    return Scaffold(
      appBar: AppPageTopActions(
        leading: const BackButton(),
        trailing: <Widget>[
          IconButton(
            onPressed: state.actionBusy || state.unreadCount == 0
                ? null
                : () => ref
                      .read(notificationsControllerProvider.notifier)
                      .markAllRead(),
            icon: const Icon(Icons.done_all_outlined),
            tooltip: '全部已读',
          ),
          IconButton(
            onPressed: state.loading
                ? null
                : () => ref
                      .read(notificationsControllerProvider.notifier)
                      .refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: AsyncPageState(
        loading: state.loading,
        error: state.error,
        onRetry: () =>
            ref.read(notificationsControllerProvider.notifier).loadInitial(),
        child: state.items.isEmpty
            ? ListView(
                children: const <Widget>[
                  SizedBox(height: 120),
                  Center(child: Text('暂时没有新的通知。')),
                ],
              )
            : RefreshIndicator(
                onRefresh: () => ref
                    .read(notificationsControllerProvider.notifier)
                    .refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (BuildContext context, int index) {
                    final NotificationItem item = state.items[index];
                    final EditorialColors colors = EditorialColors.of(context);
                    return InkWell(
                      onTap: () => _openNotification(item),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: item.isRead
                              ? Theme.of(context).colorScheme.surface
                              : Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.06),
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            CircleAvatar(
                              backgroundColor: _badgeColor(context, item.type),
                              foregroundColor: colors.onDarkPanel,
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
                                        Badge(
                                          backgroundColor: colors.danger,
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
                                        _labelForType(item.type),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.primary,
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
                  itemCount: state.items.length,
                ),
              ),
      ),
    );
  }

  Future<void> _openNotification(NotificationItem item) async {
    await ref.read(notificationsControllerProvider.notifier).markRead(item.id);
    if (!mounted) {
      return;
    }
    if (item.relatedType == 'post' && item.postId.trim().isNotEmpty) {
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
              child: const Text('关闭'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开帖子失败：$error')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开举报详情失败：$error')));
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

  Color _badgeColor(BuildContext context, String type) {
    final EditorialColors colors = EditorialColors.of(context);
    switch (type) {
      case 'comment':
        return colors.primary;
      case 'reply':
        return colors.success;
      case 'like':
        return colors.danger;
      case 'favorite':
        return colors.warning;
      case 'report_result':
        return colors.primaryActive;
      case 'system_announcement':
      default:
        return colors.mutedInk;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'comment':
        return '评论通知';
      case 'reply':
        return '回复通知';
      case 'like':
        return '点赞通知';
      case 'favorite':
        return '收藏通知';
      case 'report_result':
        return '举报结果';
      case 'system_announcement':
      default:
        return '系统公告';
    }
  }
}
