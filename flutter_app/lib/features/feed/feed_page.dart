import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/async_page_state.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';
import 'feed_controller.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  static void openFilterSheet(BuildContext context, WidgetRef ref) {
    final FeedState state = ref.read(feedControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext context) {
        return _FeedFilterSheet(initialState: state);
      },
    );
  }

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      final FeedState state = ref.read(feedControllerProvider);
      if (!state.loading || state.posts.isNotEmpty) {
        return Future<void>.value();
      }
      return ref.read(feedControllerProvider.notifier).loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final FeedState state = ref.watch(feedControllerProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.readingMaxWidth),
        child: AsyncPageState(
          loading: state.loading,
          loadingLabel: '正在读取帖子',
          error: state.error,
          onRetry: () =>
              ref.read(feedControllerProvider.notifier).loadInitial(),
          child: Column(
            children: <Widget>[
              _FeedToolbar(
                channel: state.selectedChannel,
                sort: state.sort,
                onFilter: () => FeedPage.openFilterSheet(context, ref),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(feedControllerProvider.notifier).refreshPosts(),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification notification) {
                      if (notification.metrics.extentAfter < 320) {
                        ref
                            .read(feedControllerProvider.notifier)
                            .loadMoreIfNeeded();
                      }
                      return false;
                    },
                    child: ListView.separated(
                      key: const Key('feed-list'),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        120,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        if (state.posts.isEmpty) {
                          return const _FeedEmptyState();
                        }
                        if (index == state.posts.length) {
                          return state.loadingMore
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: AppSpacing.lg,
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }
                        final PostItem post = state.posts[index];
                        return PostCard(
                          post: post,
                          onTap: () async {
                            final PostItem? updated = await openPostDetailPage(
                              context,
                              post: post,
                            );
                            if (updated == null || !mounted) {
                              return;
                            }
                            ref
                                .read(feedControllerProvider.notifier)
                                .replacePost(updated);
                          },
                          onLike: () => _toggleLike(post),
                          onFavorite: () => _toggleFavorite(post),
                        );
                      },
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemCount: state.posts.isEmpty
                          ? 1
                          : state.posts.length + (state.loadingMore ? 1 : 0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLike(PostItem post) async {
    try {
      await ref.read(feedControllerProvider.notifier).toggleLike(post);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }

  Future<void> _toggleFavorite(PostItem post) async {
    try {
      await ref.read(feedControllerProvider.notifier).toggleFavorite(post);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }
}

class _FeedToolbar extends StatelessWidget {
  const _FeedToolbar({
    required this.channel,
    required this.sort,
    required this.onFilter,
  });

  final String channel;
  final PostSort sort;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final String sortLabel = sort == PostSort.latest ? '最新' : '热度';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: AppSectionHeader(
        title: channel.isEmpty ? '帖子流' : channel,
        subtitle: '$sortLabel排序 · 下拉可刷新内容',
        trailing: OutlinedButton.icon(
          key: const Key('feed-filter-button'),
          onPressed: onFilter,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('筛选'),
        ),
      ),
    );
  }
}

class _FeedFilterSheet extends ConsumerWidget {
  const _FeedFilterSheet({required this.initialState});

  final FeedState initialState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FeedState state = ref.watch(feedControllerProvider);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        const _FilterSectionTitle('排序'),
        _FilterItem(
          label: '最新',
          selected: state.sort == PostSort.latest,
          onTap: () {
            ref
                .read(feedControllerProvider.notifier)
                .switchSort(PostSort.latest);
            Navigator.of(context).pop();
          },
        ),
        _FilterItem(
          label: '热度',
          selected: state.sort == PostSort.hot,
          onTap: () {
            ref.read(feedControllerProvider.notifier).switchSort(PostSort.hot);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 8),
        const _FilterSectionTitle('分区'),
        for (final String channel in state.channels)
          _FilterItem(
            label: channel,
            selected: state.selectedChannel == channel,
            onTap: () {
              ref.read(feedControllerProvider.notifier).switchChannel(channel);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.56),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  const _FilterItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(label),
      trailing: selected
          ? Icon(
              Icons.check_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: const AppStatePanel(
        key: Key('feed-empty-state'),
        icon: Icons.forum_outlined,
        title: '这里还没有帖子',
        message: '可以切换分区，或发布第一条内容。',
      ),
    );
  }
}
