import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';
import 'feed_controller.dart';

class DiscussionFeedView extends StatelessWidget {
  const DiscussionFeedView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetry,
    required this.onFilter,
    required this.onSortChanged,
    required this.onPostOpen,
    required this.onLike,
    required this.onFavorite,
  });

  final FeedState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final VoidCallback onFilter;
  final ValueChanged<PostSort> onSortChanged;
  final ValueChanged<PostItem> onPostOpen;
  final ValueChanged<PostItem> onLike;
  final ValueChanged<PostItem> onFavorite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktop = constraints.maxWidth >= AppBreakpoints.expanded;
        final Widget timeline = _DiscussionTimeline(
          state: state,
          onRefresh: onRefresh,
          onLoadMore: onLoadMore,
          onRetry: onRetry,
          onFilter: onFilter,
          onSortChanged: onSortChanged,
          onPostOpen: onPostOpen,
          onLike: onLike,
          onFavorite: onFavorite,
        );
        if (!desktop) {
          return timeline;
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1184),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: timeline),
                  const SizedBox(width: AppSpacing.xl),
                  SizedBox(
                    width: 304,
                    child: _DiscussionAside(
                      posts: state.posts,
                      onPostOpen: onPostOpen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiscussionTimeline extends StatelessWidget {
  const _DiscussionTimeline({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetry,
    required this.onFilter,
    required this.onSortChanged,
    required this.onPostOpen,
    required this.onLike,
    required this.onFavorite,
  });

  final FeedState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final VoidCallback onFilter;
  final ValueChanged<PostSort> onSortChanged;
  final ValueChanged<PostItem> onPostOpen;
  final ValueChanged<PostItem> onLike;
  final ValueChanged<PostItem> onFavorite;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: <Widget>[
            _DiscussionHeader(
              channel: state.selectedChannel,
              sort: state.sort,
              onFilter: onFilter,
              onSortChanged: onSortChanged,
            ),
            Expanded(
              child: _DiscussionFeedBody(
                state: state,
                onRefresh: onRefresh,
                onLoadMore: onLoadMore,
                onRetry: onRetry,
                onPostOpen: onPostOpen,
                onLike: onLike,
                onFavorite: onFavorite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscussionFeedBody extends StatelessWidget {
  const _DiscussionFeedBody({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetry,
    required this.onPostOpen,
    required this.onLike,
    required this.onFavorite,
  });

  final FeedState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final ValueChanged<PostItem> onPostOpen;
  final ValueChanged<PostItem> onLike;
  final ValueChanged<PostItem> onFavorite;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.posts.isEmpty) {
      return AppStatePanel(
        icon: Icons.cloud_off_outlined,
        title: uiText(context, zh: '内容加载失败', en: 'Could not load content'),
        message: state.error!,
        action: TextButton(
          onPressed: onRetry,
          child: Text(uiText(context, zh: '重试', en: 'Retry')),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.extentAfter < 420) {
            onLoadMore();
          }
          return false;
        },
        child: ListView.separated(
          key: const Key('discussion-feed-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: state.posts.isEmpty
              ? 1
              : state.posts.length + (state.loadingMore ? 1 : 0),
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: EditorialColors.of(context).line),
          itemBuilder: (BuildContext context, int index) {
            if (state.posts.isEmpty) {
              return SizedBox(
                height: 320,
                child: AppStatePanel(
                  icon: Icons.forum_outlined,
                  title: uiText(context, zh: '这里还没有帖子', en: 'No posts yet'),
                  message: uiText(
                    context,
                    zh: '成为第一位分享校园日常的人。',
                    en: 'Be the first to share something from campus.',
                  ),
                ),
              );
            }
            if (index == state.posts.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final PostItem post = state.posts[index];
            return PostCard(
              post: post,
              onTap: () => onPostOpen(post),
              onLike: () => onLike(post),
              onFavorite: () => onFavorite(post),
            );
          },
        ),
      ),
    );
  }
}

class _DiscussionHeader extends StatelessWidget {
  const _DiscussionHeader({
    required this.channel,
    required this.sort,
    required this.onFilter,
    required this.onSortChanged,
  });

  final String channel;
  final PostSort sort;
  final VoidCallback onFilter;
  final ValueChanged<PostSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: <Widget>[
          _DiscussionTab(
            label: uiText(context, zh: '推荐', en: 'Recommended'),
            selected: sort == PostSort.hot,
            onTap: () => onSortChanged(PostSort.hot),
          ),
          const SizedBox(width: AppSpacing.lg),
          _DiscussionTab(
            label: uiText(context, zh: '最新', en: 'Latest'),
            selected: sort == PostSort.latest,
            onTap: () => onSortChanged(PostSort.latest),
          ),
          const Spacer(),
          if (channel.isNotEmpty && channel != '全部')
            Text(channel, style: Theme.of(context).textTheme.bodySmall),
          IconButton(
            key: const Key('feed-filter-button'),
            onPressed: onFilter,
            tooltip: uiText(context, zh: '选择分区', en: 'Choose channel'),
            icon: const Icon(Icons.tune_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _DiscussionTab extends StatelessWidget {
  const _DiscussionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? colors.ink : colors.mutedInk,
          ),
        ),
      ),
    );
  }
}

class _DiscussionAside extends StatelessWidget {
  const _DiscussionAside({required this.posts, required this.onPostOpen});

  final List<PostItem> posts;
  final ValueChanged<PostItem> onPostOpen;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final List<PostItem> discussions = posts.take(5).toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    uiText(context, zh: '正在讨论', en: 'In discussion'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(Icons.trending_up_rounded, color: colors.primary),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (discussions.isEmpty)
              Text(
                uiText(context, zh: '暂时没有讨论', en: 'No discussions yet'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.mutedInk),
              )
            else
              for (final PostItem post in discussions)
                InkWell(
                  onTap: () => onPostOpen(post),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          post.title.trim().isEmpty
                              ? post.content.trim()
                              : post.title.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          uiText(
                            context,
                            zh: '${post.commentCount} 条回复',
                            en: '${post.commentCount} replies',
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.mutedInk),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: colors.line),
            const SizedBox(height: AppSpacing.md),
            Text(
              uiText(context, zh: '社区共识', en: 'Community principles'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              uiText(
                context,
                zh: '尊重每一次认真表达。匿名不等于无边界。',
                en: 'Respect every sincere contribution. Anonymity still has boundaries.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.mutedInk),
            ),
          ],
        ),
      ),
    );
  }
}
