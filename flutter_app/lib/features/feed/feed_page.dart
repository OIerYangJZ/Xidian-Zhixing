import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/state/app_theme_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/async_page_state.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';
import '../../l10n/generated/app_localizations.dart';
import 'feed_controller.dart';
import 'discussion_feed_view.dart';

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
    if (AppColorThemes.usesDiscussionLayout(AppThemeStore.instance.themeKey)) {
      return DiscussionFeedView(
        state: state,
        onRefresh: () =>
            ref.read(feedControllerProvider.notifier).refreshPosts(),
        onLoadMore: () =>
            ref.read(feedControllerProvider.notifier).loadMoreIfNeeded(),
        onRetry: () => ref.read(feedControllerProvider.notifier).loadInitial(),
        onFilter: () => FeedPage.openFilterSheet(context, ref),
        onSortChanged: (PostSort sort) =>
            ref.read(feedControllerProvider.notifier).switchSort(sort),
        onPostOpen: _openPost,
        onLike: _toggleLike,
        onFavorite: _toggleFavorite,
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktop = constraints.maxWidth >= AppBreakpoints.expanded;
        final EdgeInsets contentPadding = EdgeInsets.fromLTRB(
          desktop ? 28 : 0,
          desktop ? AppSpacing.md : 0,
          desktop ? 28 : 0,
          0,
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Padding(
              padding: contentPadding,
              child: AsyncPageState(
                loading: state.loading,
                loadingLabel: uiText(
                  context,
                  zh: '正在读取帖子',
                  en: 'Loading posts',
                ),
                error: state.error,
                onRetry: () =>
                    ref.read(feedControllerProvider.notifier).loadInitial(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppLayout.readingMaxWidth,
                        ),
                        child: Column(
                          children: <Widget>[
                            if (desktop) const _FeedManifesto(),
                            _FeedToolbar(
                              channel: state.selectedChannel,
                              sort: state.sort,
                              onFilter: () =>
                                  FeedPage.openFilterSheet(context, ref),
                              onSortChanged: (PostSort sort) => ref
                                  .read(feedControllerProvider.notifier)
                                  .switchSort(sort),
                            ),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: () => ref
                                    .read(feedControllerProvider.notifier)
                                    .refreshPosts(),
                                child: NotificationListener<ScrollNotification>(
                                  onNotification:
                                      (ScrollNotification notification) {
                                        if (notification.metrics.extentAfter <
                                            320) {
                                          ref
                                              .read(
                                                feedControllerProvider.notifier,
                                              )
                                              .loadMoreIfNeeded();
                                        }
                                        return false;
                                      },
                                  child: ListView.separated(
                                    key: const Key('feed-list'),
                                    padding: EdgeInsets.fromLTRB(
                                      desktop ? 0 : AppSpacing.md,
                                      AppSpacing.xs,
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
                                                padding: EdgeInsets.symmetric(
                                                  vertical: AppSpacing.lg,
                                                ),
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              )
                                            : const SizedBox.shrink();
                                      }
                                      final PostItem post = state.posts[index];
                                      return PostCard(
                                        post: post,
                                        onTap: () async {
                                          final PostItem? updated =
                                              await openPostDetailPage(
                                                context,
                                                post: post,
                                              );
                                          if (updated == null || !mounted) {
                                            return;
                                          }
                                          ref
                                              .read(
                                                feedControllerProvider.notifier,
                                              )
                                              .replacePost(updated);
                                        },
                                        onLike: () => _toggleLike(post),
                                        onFavorite: () => _toggleFavorite(post),
                                      );
                                    },
                                    separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color: Theme.of(context).dividerColor,
                                    ),
                                    itemCount: state.posts.isEmpty
                                        ? 1
                                        : state.posts.length +
                                              (state.loadingMore ? 1 : 0),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (desktop) ...<Widget>[
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(context, zh: '操作失败：$error', en: 'Action failed: $error'),
          ),
        ),
      );
    }
  }

  Future<void> _openPost(PostItem post) async {
    final PostItem? updated = await openPostDetailPage(context, post: post);
    if (updated == null || !mounted) {
      return;
    }
    ref.read(feedControllerProvider.notifier).replacePost(updated);
  }

  Future<void> _toggleFavorite(PostItem post) async {
    try {
      await ref.read(feedControllerProvider.notifier).toggleFavorite(post);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(context, zh: '操作失败：$error', en: 'Action failed: $error'),
          ),
        ),
      );
    }
  }
}

class _FeedManifesto extends StatelessWidget {
  const _FeedManifesto();

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Locale locale = Localizations.localeOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: colors.darkPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.appTitle,
                  style: AppTypography.accentStyle(
                    locale,
                    fontSize: 14,
                    color: colors.onDarkPanel.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.tagline,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: colors.onDarkPanel,
                    fontSize: locale.languageCode == 'en' ? 38 : 42,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 10,
                  child: ColoredBox(color: colors.coral),
                ),
              ),
              SizedBox(
                width: 140,
                height: 10,
                child: ColoredBox(color: colors.apricot),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedToolbar extends StatelessWidget {
  const _FeedToolbar({
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          _FeedTab(
            label: l10n.latest,
            selected: sort == PostSort.latest,
            onTap: () => onSortChanged(PostSort.latest),
          ),
          const SizedBox(width: AppSpacing.lg),
          _FeedTab(
            label: l10n.popular,
            selected: sort == PostSort.hot,
            onTap: () => onSortChanged(PostSort.hot),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              channel.isEmpty ? l10n.allChannels : channel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            key: const Key('feed-filter-button'),
            onPressed: onFilter,
            tooltip: l10n.filterChannels,
            icon: const Icon(Icons.tune_rounded, size: 18),
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
    final Color primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
    final bool english = Localizations.localeOf(context).languageCode == 'en';
    final List<(String, String)> topics = english
        ? const <(String, String)>[
            ('Fall course selection tips', '428'),
            ('Campus competition teams', '316'),
            ('New library opening hours', '204'),
            ('South Campus dining picks', '188'),
          ]
        : _topics;
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 40),
      children: <Widget>[
        AppSectionTitle(
          title: uiText(context, zh: '今日热议', en: 'Trending today'),
          actionLabel: uiText(context, zh: '查看热榜', en: 'View ranking'),
        ),
        for (int index = 0; index < topics.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 26,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: SharedColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    topics[index].$1,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  topics[index].$2,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Divider(color: Theme.of(context).dividerColor),
        const SizedBox(height: AppSpacing.md),
        AppSectionTitle(
          title: uiText(context, zh: '社区共识', en: 'Community principles'),
          actionLabel: uiText(context, zh: '完整规则', en: 'Full rules'),
        ),
        Container(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: SharedColors.primary, width: 2),
            ),
          ),
          child: Text(
            uiText(
              context,
              zh: '尊重每一次认真表达。匿名不等于无边界，请避免泄露个人信息，也不要传播未经核实的校园消息。',
              en: 'Respect every sincere contribution. Anonymity still has boundaries: protect personal information and do not spread unverified campus news.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Divider(color: Theme.of(context).dividerColor),
        const SizedBox(height: AppSpacing.md),
        AppSectionTitle(
          title: uiText(context, zh: '关注分区', en: 'Followed channels'),
          actionLabel: uiText(context, zh: '管理', en: 'Manage'),
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            AppStatusTag(
              label: uiText(context, zh: '校园互助', en: 'Campus help'),
            ),
            AppStatusTag(
              label: uiText(context, zh: '学习交流', en: 'Study'),
            ),
            AppStatusTag(
              label: uiText(context, zh: '社团活动', en: 'Clubs'),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeedFilterSheet extends ConsumerWidget {
  const _FeedFilterSheet({required this.initialState});

  final FeedState initialState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FeedState state = ref.watch(feedControllerProvider);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        _FilterSectionTitle(uiText(context, zh: '排序', en: 'Sort')),
        _FilterItem(
          label: l10n.latest,
          selected: state.sort == PostSort.latest,
          onTap: () {
            ref
                .read(feedControllerProvider.notifier)
                .switchSort(PostSort.latest);
            Navigator.of(context).pop();
          },
        ),
        _FilterItem(
          label: l10n.popular,
          selected: state.sort == PostSort.hot,
          onTap: () {
            ref.read(feedControllerProvider.notifier).switchSort(PostSort.hot);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 8),
        _FilterSectionTitle(uiText(context, zh: '分区', en: 'Channel')),
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
      child: AppStatePanel(
        key: const Key('feed-empty-state'),
        icon: Icons.forum_outlined,
        title: uiText(context, zh: '这里还没有帖子', en: 'No posts yet'),
        message: uiText(
          context,
          zh: '可以切换分区，或发布第一条内容。',
          en: 'Try another channel or publish the first post.',
        ),
      ),
    );
  }
}
