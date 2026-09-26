import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../core/widgets/async_page_state.dart';
import '../../design_system/design_system.dart';
import '../../models/post_item.dart';
import '../../models/public_user_profile.dart';
import '../../models/section_item.dart';
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
    final ZxTokens t = ZxTokens.of(context);
    final SearchState state = ref.watch(searchControllerProvider);
    final bool postsTab = state.selectedTab == SearchResultTab.posts;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // Lined up with the 760px results column below.
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextField(
                key: const Key('search-field'),
                controller: _queryController,
                autofocus: widget.autofocus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: uiText(
                    context,
                    zh: '搜索帖子，或按昵称搜索用户；#话题',
                    en: 'Search posts, users by nickname, or #topics',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: IconButton(
                    tooltip: uiText(context, zh: '搜索', en: 'Search'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    onPressed: state.searching ? null : _submitSearch,
                  ),
                ),
                onSubmitted: (_) => _submitSearch(),
              ),
            ),
          ),
        ),
      ),
      body: ZxPaper(
        child: AsyncPageState(
          loading: state.loading,
          error: state.error,
          onRetry: () =>
              ref.read(searchControllerProvider.notifier).loadInitial(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _SearchTab(
                        label: uiText(context, zh: '帖子', en: 'Posts'),
                        count: state.results.length,
                        selected: postsTab,
                        onTap: () => ref
                            .read(searchControllerProvider.notifier)
                            .updateTab(SearchResultTab.posts),
                      ),
                      const SizedBox(width: 20),
                      _SearchTab(
                        label: uiText(context, zh: '用户', en: 'Users'),
                        count: state.userResults.length,
                        selected: !postsTab,
                        onTap: () => ref
                            .read(searchControllerProvider.notifier)
                            .updateTab(SearchResultTab.users),
                      ),
                      const Spacer(),
                      if (postsTab) _buildPostFilters(state),
                    ],
                  ),
                  Divider(height: 1, color: t.line),
                  if (state.searching)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    const SizedBox(height: 2),
                  const SizedBox(height: 12),
                  if (postsTab)
                    _buildPosts(context, t, state)
                  else
                    _buildUsers(context, t, state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosts(BuildContext context, ZxTokens t, SearchState state) {
    if (state.results.isEmpty) {
      return _NoResults(
        keyword: state.keyword,
        what: uiText(context, zh: '帖子', en: 'posts'),
      );
    }
    return ZxCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < state.results.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: t.line),
            PostCard(
              post: state.results[i],
              highlight: state.keyword,
              onTap: () => _openPost(state.results[i]),
              onLike: () => _act(
                () => ref
                    .read(searchControllerProvider.notifier)
                    .toggleLike(state.results[i]),
              ),
              onFavorite: () => _act(
                () => ref
                    .read(searchControllerProvider.notifier)
                    .toggleFavorite(state.results[i]),
              ),
              onAuthorTap:
                  state.results[i].canViewAuthorProfile &&
                      state.results[i].authorUserId.isNotEmpty
                  ? () => _openUser(state.results[i].authorUserId)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsers(BuildContext context, ZxTokens t, SearchState state) {
    if (state.keyword.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: ZxStatePanel(
          icon: Icons.person_search_outlined,
          title: uiText(context, zh: '按昵称搜索用户', en: 'Search users by nickname'),
          message: uiText(
            context,
            zh: '只显示实名账号，匿名昵称不参与用户搜索。',
            en: 'Only real-name accounts appear; anonymous aliases are not searchable.',
          ),
        ),
      );
    }
    if (state.userResults.isEmpty) {
      return _NoResults(
        keyword: state.keyword,
        what: uiText(context, zh: '用户', en: 'users'),
      );
    }
    return ZxCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < state.userResults.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, indent: 72, color: t.line),
            _UserRow(
              user: state.userResults[i],
              keyword: state.keyword,
              onTap: () => _openUser(state.userResults[i].id),
              onFollow: state.userResults[i].canFollow
                  ? () => _act(
                      () => ref
                          .read(searchControllerProvider.notifier)
                          .toggleFollow(state.userResults[i]),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostFilters(SearchState state) {
    final Locale locale = Localizations.localeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PopupMenuButton<String>(
          tooltip: uiText(context, zh: '分区', en: 'Section'),
          enabled: !state.searching,
          onSelected: (String key) =>
              ref.read(searchControllerProvider.notifier).updateSection(key),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            CheckedPopupMenuItem<String>(
              value: '',
              checked: state.selectedSectionKey.isEmpty,
              child: Text(localizedChannel(locale, '全部')),
            ),
            for (final SectionItem section in state.sections)
              CheckedPopupMenuItem<String>(
                value: section.key,
                checked: section.key == state.selectedSectionKey,
                child: Text(section.sectionName),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: <Widget>[
                Text(
                  state.selectedSection?.sectionName ??
                      localizedChannel(locale, '全部'),
                  style: ZxType.caption.copyWith(fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.expand_more_rounded, size: 18),
              ],
            ),
          ),
        ),
        SegmentedButton<PostSort>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: <ButtonSegment<PostSort>>[
            for (final PostSort sort in _webSorts)
              ButtonSegment<PostSort>(
                value: sort,
                label: Text(
                  sort == PostSort.latest
                      ? uiText(context, zh: '最新', en: 'Latest')
                      : uiText(context, zh: '最热', en: 'Top'),
                ),
              ),
          ],
          selected: <PostSort>{state.sort},
          onSelectionChanged: state.searching
              ? null
              : (Set<PostSort> value) => ref
                    .read(searchControllerProvider.notifier)
                    .updateSort(value.first),
        ),
      ],
    );
  }

  Future<void> _openPost(PostItem post) async {
    final PostItem? updated = await openPostDetailPage(context, post: post);
    if (updated == null || !mounted) {
      return;
    }
    ref.read(searchControllerProvider.notifier).replaceResult(updated);
  }

  void _openUser(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfilePage(userId: userId),
      ),
    );
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        zxShowToast(
          context,
          uiText(context, zh: '操作失败：$error', en: 'Failed: $error'),
        );
      }
    }
  }

  Future<void> _submitSearch() {
    ref
        .read(searchControllerProvider.notifier)
        .setKeyword(_queryController.text.trim());
    return ref.read(searchControllerProvider.notifier).search();
  }
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
    final ZxTokens t = ZxTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? t.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: ZxType.label.copyWith(color: selected ? t.text : t.text3),
            ),
            const SizedBox(width: 6),
            Text('$count', style: ZxType.caption.copyWith(color: t.text3)),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.keyword,
    required this.onTap,
    required this.onFollow,
  });

  final PublicUserProfile user;
  final String keyword;
  final VoidCallback onTap;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final String name = user.nicknameFor(Localizations.localeOf(context));
    final bool mutual = user.isFollowing && user.isFollower;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            ZxAvatar(
              name: name,
              imageUrl: AppConfig.resolveUrl(user.avatarUrl),
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: highlightSpans(
                        name,
                        keyword,
                        TextStyle(color: t.primary),
                      ),
                    ),
                    style: ZxType.label.copyWith(color: t.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    uiText(
                      context,
                      zh: '${user.userLevelLabel} · ${user.postCount} 帖子 · ${user.followerCount} 粉丝',
                      en: '${user.postCount} posts · ${user.followerCount} followers',
                    ),
                    style: ZxType.caption.copyWith(color: t.text3),
                  ),
                ],
              ),
            ),
            if (onFollow != null)
              ZxButton(
                label: mutual
                    ? uiText(context, zh: '互相关注', en: 'Mutual')
                    : user.isFollowing
                    ? uiText(context, zh: '已关注', en: 'Following')
                    : uiText(context, zh: '关注', en: 'Follow'),
                variant: user.isFollowing
                    ? ZxButtonVariant.secondary
                    : ZxButtonVariant.primary,
                small: true,
                onPressed: onFollow,
              ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.keyword, required this.what});

  final String keyword;
  final String what;

  @override
  Widget build(BuildContext context) {
    final String q = keyword.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: ZxStatePanel(
        icon: Icons.search_off_rounded,
        title: q.isEmpty
            ? uiText(context, zh: '输入关键词开始搜索', en: 'Type something to search')
            : uiText(
                context,
                zh: '没有找到「$q」相关的$what',
                en: 'No $what match “$q”',
              ),
        message: q.isEmpty
            ? null
            : uiText(context, zh: '换个关键词试试。', en: 'Try another keyword.'),
      ),
    );
  }
}
