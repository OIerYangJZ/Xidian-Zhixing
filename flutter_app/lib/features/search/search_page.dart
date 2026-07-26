import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/async_page_state.dart';
import '../../models/post_item.dart';
import '../../models/public_user_profile.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';
import '../profile/public_user_profile_page.dart';
import 'search_controller.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    super.key,
    this.initialKeyword = '',
    this.autofocus = false,
  });

  final String initialKeyword;
  final bool autofocus;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const List<PostSort> _webSorts = <PostSort>[
    PostSort.latest,
    PostSort.hot,
  ];

  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.initialKeyword.trim();
    Future<void>.microtask(() async {
      final notifier = ref.read(searchControllerProvider.notifier);
      if (_queryController.text.trim().isNotEmpty) {
        notifier.setKeyword(_queryController.text.trim());
      }
      await notifier.loadInitial();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SearchState state = ref.watch(searchControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _SearchTopBar(
              controller: _queryController,
              autofocus: widget.autofocus,
              searching: state.searching,
              onBack: () => Navigator.of(context).pop(),
              onSubmit: _submitSearch,
            ),
            _SearchTabs(
              selected: state.selectedTab,
              postCount: state.results.length,
              userCount: state.userResults.length,
              onSelected: (SearchResultTab tab) =>
                  ref.read(searchControllerProvider.notifier).updateTab(tab),
            ),
            Divider(height: 1, color: EditorialColors.of(context).line),
            Expanded(
              child: AsyncPageState(
                loading: state.loading,
                error: state.error,
                onRetry: () =>
                    ref.read(searchControllerProvider.notifier).loadInitial(),
                child: _SearchResults(
                  state: state,
                  onSelectPost: _openPost,
                  onSelectUser: _openUser,
                  postFilters: _buildPostFilters(state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostFilters(SearchState state) {
    final notifier = ref.read(searchControllerProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _SearchFilterMenu<String>(
            label: '频道',
            value: state.selectedChannel,
            values: state.channels,
            valueLabel: (String value) => value,
            enabled: !state.searching,
            onSelected: notifier.updateChannel,
          ),
          const SizedBox(width: AppSpacing.xxs),
          _SearchFilterMenu<PostSort>(
            label: '排序',
            value: state.sort,
            values: _webSorts,
            valueLabel: (PostSort value) => value.label,
            enabled: !state.searching,
            onSelected: notifier.updateSort,
          ),
        ],
      ),
    );
  }

  Future<void> _openPost(PostItem post) async {
    final PostItem? updated = await openPostDetailPage(context, post: post);
    if (updated == null || !mounted) {
      return;
    }
    ref.read(searchControllerProvider.notifier).replaceResult(updated);
  }

  void _openUser(PublicUserProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfilePage(userId: profile.id),
      ),
    );
  }

  Future<void> _submitSearch() {
    ref
        .read(searchControllerProvider.notifier)
        .setKeyword(_queryController.text.trim());
    return ref.read(searchControllerProvider.notifier).search();
  }
}

class _SearchTopBar extends StatelessWidget {
  const _SearchTopBar({
    required this.controller,
    required this.autofocus,
    required this.searching,
    required this.onBack,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool autofocus;
  final bool searching;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: onBack,
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSubmit(),
                  decoration: AppInput.searchDecoration(
                    hintText: '搜索',
                    suffixIcon: IconButton(
                      onPressed: searching ? null : onSubmit,
                      tooltip: '开始搜索',
                      icon: const Icon(Icons.arrow_forward_rounded),
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
}

class _SearchTabs extends StatelessWidget {
  const _SearchTabs({
    required this.selected,
    required this.postCount,
    required this.userCount,
    required this.onSelected,
  });

  final SearchResultTab selected;
  final int postCount;
  final int userCount;
  final ValueChanged<SearchResultTab> onSelected;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SearchTab(
              label: '帖子',
              count: postCount,
              selected: selected == SearchResultTab.posts,
              onTap: () => onSelected(SearchResultTab.posts),
            ),
          ),
          Expanded(
            child: _SearchTab(
              label: '用户',
              count: userCount,
              selected: selected == SearchResultTab.users,
              onTap: () => onSelected(SearchResultTab.users),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SearchTab extends StatelessWidget {
  const _SearchTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Material(
      color: colors.surface.withValues(alpha: 0),
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.resolve(context, AppMotion.standard),
          curve: AppMotion.emphasis,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? colors.primary : colors.surface,
                width: 3,
              ),
            ),
          ),
          child: Text(
            '$label $count',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: selected ? colors.ink : colors.mutedInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.state,
    required this.onSelectPost,
    required this.onSelectUser,
    required this.postFilters,
  });

  final SearchState state;
  final ValueChanged<PostItem> onSelectPost;
  final ValueChanged<PublicUserProfile> onSelectUser;
  final Widget postFilters;

  @override
  Widget build(BuildContext context) {
    final bool postTab = state.selectedTab == SearchResultTab.posts;
    final int count = postTab ? state.results.length : state.userResults.length;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            if (postTab) ...<Widget>[
              postFilters,
              const SizedBox(height: AppSpacing.sm),
            ],
            if (state.searching)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            Text('$count 个结果', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            if (postTab) ..._postResults(context) else ..._userResults(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _postResults(BuildContext context) {
    if (state.results.isEmpty) {
      return <Widget>[const _SearchEmptyState(message: '没有匹配帖子')];
    }
    return <Widget>[
      for (int index = 0; index < state.results.length; index++) ...<Widget>[
        PostCard(
          post: state.results[index],
          onTap: () => onSelectPost(state.results[index]),
        ),
        if (index != state.results.length - 1) const Divider(height: 1),
      ],
    ];
  }

  List<Widget> _userResults(BuildContext context) {
    if (state.keyword.trim().isEmpty) {
      return <Widget>[const _SearchEmptyState(message: '输入昵称后即可搜索用户')];
    }
    if (state.userResults.isEmpty) {
      return <Widget>[const _SearchEmptyState(message: '没有匹配用户')];
    }
    return <Widget>[
      for (
        int index = 0;
        index < state.userResults.length;
        index++
      ) ...<Widget>[
        _UserSearchRow(
          profile: state.userResults[index],
          onTap: () => onSelectUser(state.userResults[index]),
        ),
        if (index != state.userResults.length - 1)
          const Divider(height: 1, indent: 64),
      ],
    ];
  }
}

class _SearchFilterMenu<T> extends StatelessWidget {
  const _SearchFilterMenu({
    required this.label,
    required this.value,
    required this.values,
    required this.valueLabel,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) valueLabel;
  final bool enabled;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return PopupMenuButton<T>(
      enabled: enabled,
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => values
          .map(
            (T item) =>
                PopupMenuItem<T>(value: item, child: Text(valueLabel(item))),
          )
          .toList(growable: false),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              valueLabel(value),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: enabled ? colors.ink : colors.faintInk,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: enabled ? colors.mutedInk : colors.faintInk,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserSearchRow extends StatelessWidget {
  const _UserSearchRow({required this.profile, required this.onTap});

  final PublicUserProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final String resolvedAvatar = AppConfig.resolveUrl(profile.avatarUrl);
    final String fallback = profile.nickname.trim().isEmpty
        ? '?'
        : profile.nickname.trim().characters.first;
    return AppHoverSurface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: colors.primarySubtle,
              backgroundImage: resolvedAvatar.isEmpty
                  ? null
                  : NetworkImage(resolvedAvatar),
              child: resolvedAvatar.isEmpty
                  ? Text(fallback, style: TextStyle(color: colors.primary))
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    profile.nickname,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '帖子 ${profile.postCount} · 粉丝 ${profile.followerCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (profile.isFollowing)
              Text(
                '已关注',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: colors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
    child: Center(
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    ),
  );
}
