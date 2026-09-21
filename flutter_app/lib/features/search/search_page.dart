import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
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
  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.initialKeyword.trim();
    Future<void>.microtask(() async {
      final SearchController notifier = ref.read(
        searchControllerProvider.notifier,
      );
      notifier.updateSort(PostSort.hot);
      if (_queryController.text.trim().isNotEmpty)
        notifier.setKeyword(_queryController.text.trim());
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
    final bool desktop = AppBreakpoints.isDesktop(context);
    final double scale = desktop
        ? AppLayout.shellScale(MediaQuery.sizeOf(context).width)
        : 1;
    final EditorialColors colors = EditorialColors.of(context);
    final BorderRadius panelRadius = desktop
        ? BorderRadius.vertical(top: Radius.circular(34 * scale))
        : BorderRadius.zero;

    return Container(
      color: colors.page,
      child: Column(
        children: <Widget>[
          _SearchHeader(
            controller: _queryController,
            autofocus: widget.autofocus,
            scale: scale,
            desktop: desktop,
            onSubmit: _submitSearch,
            onFilter: () => _openFilters(state),
          ),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.line),
                borderRadius: panelRadius,
              ),
              child: Column(
                children: <Widget>[
                  _SearchTabs(
                    state: state,
                    scale: scale,
                    desktop: desktop,
                    onChanged: (SearchResultTab tab) {
                      ref
                          .read(searchControllerProvider.notifier)
                          .updateTab(tab);
                    },
                    onSortChanged: (PostSort sort) {
                      ref
                          .read(searchControllerProvider.notifier)
                          .updateSort(sort);
                      ref
                          .read(searchControllerProvider.notifier)
                          .updateTab(SearchResultTab.posts);
                    },
                  ),
                  Expanded(
                    child: AsyncPageState(
                      loading: state.loading,
                      error: state.error,
                      onRetry: () => ref
                          .read(searchControllerProvider.notifier)
                          .loadInitial(),
                      child: state.selectedTab == SearchResultTab.users
                          ? _UserResults(
                              state: state,
                              scale: scale,
                              desktop: desktop,
                            )
                          : _PostResults(
                              state: state,
                              scale: scale,
                              desktop: desktop,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSearch() {
    ref
        .read(searchControllerProvider.notifier)
        .setKeyword(_queryController.text.trim());
    return ref.read(searchControllerProvider.notifier).search();
  }

  Future<void> _openFilters(SearchState state) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: EditorialColors.of(context).surface,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                uiText(context, zh: '筛选', en: 'Filters'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                uiText(context, zh: '频道', en: 'Channel'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: state.selectedChannel,
                items: state.channels
                    .map(
                      (String channel) => DropdownMenuItem<String>(
                        value: channel,
                        child: Text(channel),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value != null)
                    ref
                        .read(searchControllerProvider.notifier)
                        .updateChannel(value);
                  Navigator.of(sheetContext).pop();
                },
              ),
              const SizedBox(height: 16),
              Text(
                uiText(context, zh: '排序', en: 'Sort'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              RadioGroup<PostSort>(
                groupValue: state.sort,
                onChanged: (PostSort? value) {
                  if (value != null) {
                    ref
                        .read(searchControllerProvider.notifier)
                        .updateSort(value);
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: Column(
                  children: <Widget>[
                    RadioListTile<PostSort>(
                      value: PostSort.hot,
                      title: Text(uiText(context, zh: '热门', en: 'Top')),
                    ),
                    RadioListTile<PostSort>(
                      value: PostSort.latest,
                      title: Text(uiText(context, zh: '最新', en: 'Recent')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.autofocus,
    required this.scale,
    required this.desktop,
    required this.onSubmit,
    required this.onFilter,
  });
  final TextEditingController controller;
  final bool autofocus;
  final double scale;
  final bool desktop;
  final VoidCallback onSubmit;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final double horizontal = desktop ? 0 : 16;
    final double top = desktop ? 26 * scale : 12;
    final double fieldHeight = desktop ? 61 * scale : 52;
    final double iconSize = desktop ? 28 * scale : 22;
    return SizedBox(
      height: desktop ? 100 * scale : 74,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          top,
          desktop ? 33 * scale : 16,
          desktop ? 13 * scale : 10,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: fieldHeight,
                padding: EdgeInsets.symmetric(
                  horizontal: desktop ? 30 * scale : 18,
                ),
                decoration: BoxDecoration(
                  color: colors.primarySubtle,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.search, size: iconSize, color: colors.mutedInk),
                    SizedBox(width: 15 * scale),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autofocus: autofocus,
                        onSubmitted: (_) => onSubmit(),
                        style: TextStyle(
                          fontSize: desktop ? 22 * scale : 16,
                          color: colors.ink,
                          height: 1.3,
                        ),
                        decoration: InputDecoration(
                          hintText: uiText(context, zh: '搜索', en: 'Search'),
                          hintStyle: TextStyle(
                            fontSize: desktop ? 22 * scale : 16,
                            color: colors.mutedInk,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onFilter,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: 34 * scale,
                        height: 34 * scale,
                      ),
                      icon: Icon(
                        Icons.tune,
                        size: iconSize,
                        color: colors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: desktop ? 27 * scale : 8),
            IconButton(
              onPressed: () {},
              tooltip: uiText(context, zh: '更多选项', en: 'More options'),
              icon: Icon(
                Icons.more_horiz,
                size: desktop ? 30 * scale : 24,
                color: colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchTabs extends StatelessWidget {
  const _SearchTabs({
    required this.state,
    required this.scale,
    required this.desktop,
    required this.onChanged,
    required this.onSortChanged,
  });
  final SearchState state;
  final double scale;
  final bool desktop;
  final ValueChanged<SearchResultTab> onChanged;
  final ValueChanged<PostSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final double height = desktop ? 83 * scale : 56;
    final double fontSize = desktop ? 22 * scale : 15;
    final bool users = state.selectedTab == SearchResultTab.users;
    return SizedBox(
      height: height,
      child: Row(
        children: <Widget>[
          _TabButton(
            label: uiText(context, zh: '热门', en: 'Top'),
            active: !users && state.sort == PostSort.hot,
            fontSize: fontSize,
            onTap: () {
              onChanged(SearchResultTab.posts);
              onSortChanged(PostSort.hot);
            },
            color: colors.ink,
            muted: colors.mutedInk,
          ),
          _TabButton(
            label: uiText(context, zh: '最新', en: 'Recent'),
            active: !users && state.sort == PostSort.latest,
            fontSize: fontSize,
            onTap: () {
              onChanged(SearchResultTab.posts);
              onSortChanged(PostSort.latest);
            },
            color: colors.ink,
            muted: colors.mutedInk,
          ),
          _TabButton(
            label: uiText(context, zh: '用户', en: 'Profiles'),
            active: users,
            fontSize: fontSize,
            onTap: () => onChanged(SearchResultTab.users),
            color: colors.ink,
            muted: colors.mutedInk,
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.fontSize,
    required this.onTap,
    required this.color,
    required this.muted,
  });
  final String label;
  final bool active;
  final double fontSize;
  final VoidCallback onTap;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: active ? color : Colors.transparent),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? color : muted,
            fontSize: fontSize,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _PostResults extends StatelessWidget {
  const _PostResults({
    required this.state,
    required this.scale,
    required this.desktop,
  });
  final SearchState state;
  final double scale;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    if (state.searching && state.results.isEmpty)
      return const Center(child: CircularProgressIndicator());
    if (state.results.isEmpty)
      return Center(
        child: Text(
          uiText(context, zh: '没有找到匹配的帖子。', en: 'No posts match your search.'),
        ),
      );
    return ListView.builder(
      itemCount: state.results.length,
      padding: EdgeInsets.only(bottom: desktop ? 100 * scale : 80),
      itemBuilder: (BuildContext context, int index) {
        final PostItem post = state.results[index];
        return PostCard(
          post: post,
          onTap: () => openPostDetailPage(context, post: post),
        );
      },
    );
  }
}

class _UserResults extends StatelessWidget {
  const _UserResults({
    required this.state,
    required this.scale,
    required this.desktop,
  });
  final SearchState state;
  final double scale;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    if (state.searching && state.userResults.isEmpty)
      return const Center(child: CircularProgressIndicator());
    if (state.userResults.isEmpty)
      return Center(
        child: Text(
          uiText(
            context,
            zh: '没有找到匹配昵称的用户。',
            en: 'No profiles match your search.',
          ),
        ),
      );
    final double avatarSize = desktop ? 50 * scale : 42;
    return ListView.builder(
      itemCount: state.userResults.length,
      padding: EdgeInsets.only(bottom: desktop ? 100 * scale : 80),
      itemBuilder: (BuildContext context, int index) {
        final PublicUserProfile profile = state.userResults[index];
        final String avatar = AppConfig.resolveUrl(profile.avatarUrl);
        final String fallback = profile.nickname.trim().isEmpty
            ? '?'
            : profile.nickname.trim().characters.first;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PublicUserProfilePage(userId: profile.id),
              ),
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                desktop ? 33 * scale : 16,
                desktop ? 22 * scale : 16,
                desktop ? 33 * scale : 16,
                desktop ? 23 * scale : 16,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: avatarSize / 2,
                    backgroundColor: colors.primarySubtle,
                    backgroundImage: avatar.isEmpty
                        ? null
                        : NetworkImage(avatar),
                    child: avatar.isEmpty
                        ? Text(
                            fallback,
                            style: TextStyle(
                              fontSize: avatarSize * .42,
                              color: colors.primary,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: desktop ? 17 * scale : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          profile.nickname,
                          style: TextStyle(
                            fontSize: desktop ? 22 * scale : 16,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                          ),
                        ),
                        SizedBox(height: 4 * scale),
                        Text(
                          uiText(
                            context,
                            zh: '${profile.userLevelLabel} · 帖子 ${profile.postCount} · 粉丝 ${profile.followerCount}',
                            en: '${profile.postCount} posts · ${profile.followerCount} followers',
                          ),
                          style: TextStyle(
                            fontSize: desktop ? 18 * scale : 13,
                            height: 1.4,
                            color: colors.mutedInk,
                          ),
                        ),
                      ],
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
