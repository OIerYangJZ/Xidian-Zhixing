import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/async_page_state.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';
import '../post/create_post_page.dart';
import '../search/search_page.dart';
import 'feed_controller.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  static void openFilterSheet(BuildContext context, WidgetRef ref) {
    final FeedState state = ref.read(feedControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => _FeedFilterSheet(initialState: state),
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktop = constraints.maxWidth >= AppBreakpoints.medium;
        final EdgeInsets pagePadding = desktop
            ? const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                0,
              )
            : EdgeInsets.zero;
        final bool showAside =
            constraints.maxWidth >=
            AppLayout.readingMaxWidth +
                AppLayout.asideWidth +
                AppSpacing.xl +
                pagePadding.horizontal;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Padding(
              padding: pagePadding,
              child: AsyncPageState(
                loading: state.loading,
                loadingLabel: '正在读取帖子',
                error: state.error,
                onRetry: () =>
                    ref.read(feedControllerProvider.notifier).loadInitial(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppLayout.readingMaxWidth,
                          ),
                          child: Column(
                            children: <Widget>[
                              _FeedHeader(
                                channel: state.selectedChannel,
                                sort: state.sort,
                                onFilter: () =>
                                    FeedPage.openFilterSheet(context, ref),
                                onSortChanged: (PostSort sort) => ref
                                    .read(feedControllerProvider.notifier)
                                    .switchSort(sort),
                              ),
                              const _PostComposer(),
                              Expanded(
                                child: _PostList(
                                  state: state,
                                  desktop: desktop,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (showAside) ...<Widget>[
                      const SizedBox(width: AppSpacing.xl),
                      const SizedBox(
                        width: AppLayout.asideWidth,
                        child: _FeedAside(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

  Widget _PostList({required FeedState state, required bool desktop}) {
    return RefreshIndicator(
      onRefresh: () => ref.read(feedControllerProvider.notifier).refreshPosts(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.extentAfter < 320) {
            ref.read(feedControllerProvider.notifier).loadMoreIfNeeded();
          }
          return false;
        },
        child: ListView.separated(
          key: const Key('feed-list'),
          padding: EdgeInsets.fromLTRB(
            desktop ? 0 : AppSpacing.md,
            0,
            desktop ? 0 : AppSpacing.md,
            120,
          ),
          itemBuilder: (BuildContext context, int index) {
            if (state.posts.isEmpty) {
              return const _FeedEmptyState();
            }
            if (index == state.posts.length) {
              return state.loadingMore
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
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
                ref.read(feedControllerProvider.notifier).replacePost(updated);
              },
              onLike: () => _toggleLike(post),
              onFavorite: () => _toggleFavorite(post),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: state.posts.isEmpty
              ? 1
              : state.posts.length + (state.loadingMore ? 1 : 0),
        ),
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        0,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '树洞',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const Key('feed-filter-button'),
                onPressed: onFilter,
                tooltip: '筛选分区',
                icon: const Icon(Icons.tune_rounded, size: 19),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              _FeedTab(
                label: '推荐',
                selected: sort == PostSort.hot,
                onTap: () => onSortChanged(PostSort.hot),
              ),
              const SizedBox(width: AppSpacing.lg),
              _FeedTab(
                label: '最新',
                selected: sort == PostSort.latest,
                onTap: () => onSortChanged(PostSort.latest),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  channel.isEmpty ? '全部分区' : channel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
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
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.standard),
        curve: AppMotion.emphasis,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? colors.primary
                  : colors.surface.withValues(alpha: 0),
              width: 2,
            ),
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.resolve(context, AppMotion.fast),
          curve: AppMotion.emphasis,
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
            color: selected ? colors.ink : colors.mutedInk,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _PostComposer extends StatefulWidget {
  const _PostComposer();

  @override
  State<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<_PostComposer> {
  bool _hovered = false;

  Future<void> _openComposer() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const CreatePostPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: AppMotion.resolve(context, AppMotion.standard),
          curve: AppMotion.emphasis,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(
              color: _hovered
                  ? colors.primary.withValues(alpha: 0.44)
                  : colors.line,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '匿',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: colors.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: InkWell(
                  onTap: _openComposer,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      '分享此刻的想法…',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.faintInk),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(onPressed: _openComposer, child: const Text('发布')),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedAside extends StatelessWidget {
  const _FeedAside();

  static const List<(String, String)> _topics = <(String, String)>[
    ('秋季选课经验集中帖', '428'),
    ('校赛报名与组队互助', '316'),
    ('新图书馆开放时间', '204'),
    ('南校区食堂窗口推荐', '188'),
  ];

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
      children: <Widget>[
        TextField(
          readOnly: true,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SearchPage(autofocus: true),
            ),
          ),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: '搜索校园内容',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _AsideSection(
          title: '今日热议',
          action: '查看热榜',
          child: Column(
            children: <Widget>[
              for (int index = 0; index < _topics.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${index + 1}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: colors.primary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _topics[index].$1,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _topics[index].$2,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _AsideSection(
          title: '社区共识',
          action: '完整规则',
          child: Container(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: colors.primary, width: 2)),
            ),
            child: Text(
              '尊重每一次认真表达。匿名不等于无边界，请避免泄露个人信息，也不要传播未经核实的校园消息。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _AsideSection(
          title: '关注分区',
          action: '管理',
          child: const Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              AppStatusTag(label: '校园互助'),
              AppStatusTag(label: '学习交流'),
              AppStatusTag(label: '社团活动'),
            ],
          ),
        ),
      ],
    );
  }
}

class _AsideSection extends StatelessWidget {
  const _AsideSection({
    required this.title,
    required this.action,
    required this.child,
  });

  final String title;
  final String action;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      AppSectionTitle(title: title, actionLabel: action),
      const SizedBox(height: AppSpacing.xs),
      child,
    ],
  );
}

class _FeedFilterSheet extends ConsumerWidget {
  const _FeedFilterSheet({required this.initialState});

  final FeedState initialState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FeedState state = ref.watch(feedControllerProvider);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: <Widget>[
        const _FilterSectionTitle('排序'),
        _FilterItem(
          label: '推荐',
          selected: state.sort == PostSort.hot,
          onTap: () {
            ref.read(feedControllerProvider.notifier).switchSort(PostSort.hot);
            Navigator.of(context).pop();
          },
        ),
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
        const SizedBox(height: AppSpacing.xs),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xxs,
      AppSpacing.sm,
      AppSpacing.xxs,
      AppSpacing.xs,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: EditorialColors.of(context).mutedInk,
      ),
    ),
  );
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
  Widget build(BuildContext context) => ListTile(
    dense: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    title: Text(label),
    trailing: selected
        ? Icon(Icons.check_rounded, color: EditorialColors.of(context).primary)
        : null,
    onTap: onTap,
  );
}

class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 260,
    child: AppStatePanel(
      key: Key('feed-empty-state'),
      icon: Icons.forum_outlined,
      title: '这里还没有帖子',
      message: '成为第一位分享校园日常的人。',
    ),
  );
}
