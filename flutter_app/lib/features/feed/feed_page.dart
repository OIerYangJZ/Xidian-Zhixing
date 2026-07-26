import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';
import '../profile/public_user_profile_page.dart';
import '../search/search_page.dart';
import 'feed_controller.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  static void openFilterDialog(BuildContext context, WidgetRef ref) {
    showAppDialog<void>(
      context: context,
      builder: (BuildContext context) => const _FeedFilterDialog(),
    );
  }

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final TextEditingController _asideSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final FeedState state = ref.read(feedControllerProvider);
      if (!state.loading || state.posts.isNotEmpty) return;
      await ref.read(feedControllerProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _asideSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FeedState state = ref.watch(feedControllerProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktop = constraints.maxWidth >= AppBreakpoints.medium;
        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification.metrics.extentAfter < 420) {
              ref.read(feedControllerProvider.notifier).loadMoreIfNeeded();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(feedControllerProvider.notifier).refreshPosts(),
            child: ScrollConfiguration(
              behavior: const _FeedScrollBehavior(),
              child: CustomScrollView(
                key: const Key('feed-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: _FeedBody(
                      state: state,
                      desktop: desktop,
                      asideSearchController: _asideSearchController,
                      onFilter: () => FeedPage.openFilterDialog(context, ref),
                      onSortChanged: (PostSort sort) => ref
                          .read(feedControllerProvider.notifier)
                          .switchSort(sort),
                      onPostOpen: _openPost,
                      onAuthorOpen: _openAuthor,
                      onLike: _toggleLike,
                      onFavorite: _toggleFavorite,
                      onHashtagOpen: _openHashtag,
                      onSearch: _openSearch,
                      onRetry: () => ref
                          .read(feedControllerProvider.notifier)
                          .loadInitial(),
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

  Future<void> _toggleLike(PostItem post) async {
    try {
      await ref.read(feedControllerProvider.notifier).toggleLike(post);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }

  Future<void> _toggleFavorite(PostItem post) async {
    try {
      await ref.read(feedControllerProvider.notifier).toggleFavorite(post);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }

  Future<void> _openPost(PostItem post) async {
    final PostItem? updated = await openPostDetailPage(context, post: post);
    if (updated == null || !mounted) return;
    ref.read(feedControllerProvider.notifier).replacePost(updated);
  }

  void _openAuthor(PostItem post) {
    if (post.authorUserId.trim().isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfilePage(userId: post.authorUserId),
      ),
    );
  }

  void _openHashtag(String hashtag) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(initialKeyword: hashtag),
      ),
    );
  }

  void _openSearch() {
    final String query = _asideSearchController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SearchPage(initialKeyword: query, autofocus: query.isEmpty),
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.state,
    required this.desktop,
    required this.asideSearchController,
    required this.onFilter,
    required this.onSortChanged,
    required this.onPostOpen,
    required this.onAuthorOpen,
    required this.onLike,
    required this.onFavorite,
    required this.onHashtagOpen,
    required this.onSearch,
    required this.onRetry,
  });

  final FeedState state;
  final bool desktop;
  final TextEditingController asideSearchController;
  final VoidCallback onFilter;
  final ValueChanged<PostSort> onSortChanged;
  final ValueChanged<PostItem> onPostOpen;
  final ValueChanged<PostItem> onAuthorOpen;
  final ValueChanged<PostItem> onLike;
  final ValueChanged<PostItem> onFavorite;
  final ValueChanged<String> onHashtagOpen;
  final VoidCallback onSearch;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Widget timeline = _FeedTimeline(
      state: state,
      onFilter: onFilter,
      onSortChanged: onSortChanged,
      onPostOpen: onPostOpen,
      onAuthorOpen: onAuthorOpen,
      onLike: onLike,
      onFavorite: onFavorite,
      onHashtagOpen: onHashtagOpen,
      onRetry: onRetry,
    );
    if (!desktop) return timeline;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: timeline),
              const SizedBox(width: AppSpacing.xl),
              SizedBox(
                width: AppLayout.asideWidth,
                child: _FeedAside(
                  controller: asideSearchController,
                  posts: state.posts,
                  onSearch: onSearch,
                  onPostOpen: onPostOpen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedTimeline extends StatelessWidget {
  const _FeedTimeline({
    required this.state,
    required this.onFilter,
    required this.onSortChanged,
    required this.onPostOpen,
    required this.onAuthorOpen,
    required this.onLike,
    required this.onFavorite,
    required this.onHashtagOpen,
    required this.onRetry,
  });

  final FeedState state;
  final VoidCallback onFilter;
  final ValueChanged<PostSort> onSortChanged;
  final ValueChanged<PostItem> onPostOpen;
  final ValueChanged<PostItem> onAuthorOpen;
  final ValueChanged<PostItem> onLike;
  final ValueChanged<PostItem> onFavorite;
  final ValueChanged<String> onHashtagOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: <Widget>[
        _FeedHeader(
          channel: state.selectedChannel,
          sort: state.sort,
          onFilter: onFilter,
          onSortChanged: onSortChanged,
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: AppInlineMessage(
              title: '内容加载失败',
              message: state.error!,
              tone: AppMessageTone.error,
              action: TextButton(onPressed: onRetry, child: const Text('重试')),
            ),
          ),
        if (state.posts.isEmpty)
          const _FeedEmptyState()
        else
          for (int index = 0; index < state.posts.length; index++) ...<Widget>[
            PostCard(
              post: state.posts[index],
              onTap: () => onPostOpen(state.posts[index]),
              onOpenPost: () => onPostOpen(state.posts[index]),
              onAuthorTap: () => onAuthorOpen(state.posts[index]),
              onLike: () => onLike(state.posts[index]),
              onFavorite: () => onFavorite(state.posts[index]),
              onHashtagTap: onHashtagOpen,
            ),
            if (index != state.posts.length - 1)
              Divider(height: 1, color: colors.line),
          ],
        if (state.loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
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
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
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
          const Spacer(),
          if (channel.isNotEmpty && channel != '全部')
            Text(
              channel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          IconButton(
            key: const Key('feed-filter-button'),
            onPressed: onFilter,
            tooltip: '选择分区',
            icon: const Icon(Icons.tune_rounded, size: 19),
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
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.standard),
        curve: AppMotion.emphasis,
        height: 48,
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

class _FeedAside extends StatelessWidget {
  const _FeedAside({
    required this.controller,
    required this.posts,
    required this.onSearch,
    required this.onPostOpen,
  });

  final TextEditingController controller;
  final List<PostItem> posts;
  final VoidCallback onSearch;
  final ValueChanged<PostItem> onPostOpen;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final List<PostItem> discussions = posts.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
          decoration: AppInput.searchDecoration(
            hintText: '搜索',
            suffixIcon: IconButton(
              onPressed: onSearch,
              tooltip: '搜索',
              icon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (discussions.isNotEmpty) ...<Widget>[
          Text('正在讨论', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final PostItem post in discussions)
            _AsideDiscussionRow(post: post, onTap: () => onPostOpen(post)),
        ] else
          Text(
            '暂时没有讨论',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.mutedInk),
          ),
      ],
    );
  }
}

class _AsideDiscussionRow extends StatelessWidget {
  const _AsideDiscussionRow({required this.post, required this.onTap});

  final PostItem post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Material(
      color: colors.surface.withValues(alpha: 0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                post.title.trim().isEmpty
                    ? post.content.trim()
                    : post.title.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${post.commentCount} 条回复',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.mutedInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedFilterDialog extends ConsumerWidget {
  const _FeedFilterDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FeedState state = ref.watch(feedControllerProvider);
    final List<String> regular = state.channels;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: <Widget>[
        const _FilterSectionTitle('分区'),
        for (final String channel in regular)
          _FilterItem(
            label: channel,
            selected: state.selectedChannel == channel,
            onTap: () {
              ref.read(feedControllerProvider.notifier).switchChannel(channel);
              Navigator.of(context).pop();
            },
          ),
        if (state.collegeSections.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          const _FilterSectionTitle('学院分区'),
          for (final ForumSection section in state.collegeSections)
            _FilterItem(
              label: section.name,
              selected: state.selectedSectionId == section.id,
              onTap: () {
                ref
                    .read(feedControllerProvider.notifier)
                    .switchCollegeSection(section);
                Navigator.of(context).pop();
              },
            ),
        ],
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

class _FeedScrollBehavior extends MaterialScrollBehavior {
  const _FeedScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
