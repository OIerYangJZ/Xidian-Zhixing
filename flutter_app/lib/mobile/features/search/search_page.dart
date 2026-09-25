import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xdu_treehole_web/core/config/app_config.dart';
import 'package:xdu_treehole_web/design_system/design_system.dart';
import 'package:xdu_treehole_web/features/search/search_controller.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/models/public_user_profile.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'package:xdu_treehole_web/widgets/post_card.dart';

import '../../core/utils/time_utils.dart';

/// 搜索 (handoff S1 / S3). One query searches posts and users at once, so
/// both tabs show a count. A query starting with # is a topic: a topic card
/// heads the posts with 最新 / 最热. With nothing found, a few topics are
/// offered instead.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialKeyword = ''});

  final String initialKeyword;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const List<String> _fallbackTopics = <String>[
    '图书馆',
    '组队',
    '二手',
    '考研',
    '失物招领',
  ];

  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// The query as submitted, with its #; the controller gets it without.
  String _submitted = '';
  List<String> _topics = const <String>[];

  bool get _isTopic => _submitted.startsWith('#') && _submitted.length > 1;

  @override
  void initState() {
    super.initState();
    _query.text = widget.initialKeyword.trim();
    _query.addListener(() => setState(() {}));
    Future<void>.microtask(() async {
      final notifier = ref.read(searchControllerProvider.notifier);
      // An empty query loads the latest posts; their tags seed the topic
      // suggestions before anything is searched.
      notifier.setKeyword('');
      await notifier.loadInitial();
      if (!mounted) return;
      _topics = _topTags(ref.read(searchControllerProvider).results);
      if (_query.text.trim().isNotEmpty) {
        await _submit();
      } else {
        setState(() {});
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<String> _topTags(List<PostItem> posts) {
    final Map<String, int> counts = <String, int>{};
    for (final PostItem post in posts) {
      for (final String tag in post.tags) {
        final String name = tag.trim();
        if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final List<String> ranked = counts.keys.toList()
      ..sort((String a, String b) => counts[b]!.compareTo(counts[a]!));
    return ranked.isEmpty ? _fallbackTopics : ranked.take(5).toList();
  }

  Future<void> _submit([String? text]) async {
    if (text != null) {
      _query.text = text;
      _query.selection = TextSelection.collapsed(offset: text.length);
    }
    final String raw = _query.text.trim();
    if (raw.isEmpty) return;
    _focus.unfocus();
    setState(() => _submitted = raw);
    final notifier = ref.read(searchControllerProvider.notifier);
    notifier.setKeyword(raw.startsWith('#') ? raw.substring(1).trim() : raw);
    await notifier.search();
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) zxShowToast(context, '操作失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final SearchState state = ref.watch(searchControllerProvider);
    final bool postsTab = state.selectedTab == SearchResultTab.posts;
    final bool searched = _submitted.isNotEmpty;

    return Scaffold(
      backgroundColor: t.surface,
      appBar: AppBar(
        backgroundColor: t.surface,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              tooltip: '返回',
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.canPop() ? context.pop() : null,
            ),
            Expanded(child: _buildField(t)),
            TextButton(
              key: const Key('mobile-search-submit'),
              onPressed: state.searching ? null : _submit,
              style: TextButton.styleFrom(foregroundColor: t.primary),
              child: const Text('搜索'),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (searched)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _Tab(
                    key: const Key('mobile-search-tab-posts'),
                    label: '帖子',
                    count: state.results.length,
                    selected: postsTab,
                    onTap: () => ref
                        .read(searchControllerProvider.notifier)
                        .updateTab(SearchResultTab.posts),
                  ),
                  const SizedBox(width: 24),
                  _Tab(
                    key: const Key('mobile-search-tab-users'),
                    label: '用户',
                    count: state.userResults.length,
                    selected: !postsTab,
                    onTap: () => ref
                        .read(searchControllerProvider.notifier)
                        .updateTab(SearchResultTab.users),
                  ),
                ],
              ),
            ),
          Divider(height: 1, color: t.line),
          SizedBox(
            height: 2,
            child: state.searching || state.loading
                ? const LinearProgressIndicator(minHeight: 2)
                : null,
          ),
          Expanded(
            child: ColoredBox(
              color: t.bg,
              child: state.error != null
                  ? ZxStatePanel(
                      error: true,
                      icon: Icons.error_outline_rounded,
                      title: '搜索失败',
                      message: state.error,
                      actionLabel: '重试',
                      onAction: searched
                          ? _submit
                          : () => ref
                                .read(searchControllerProvider.notifier)
                                .loadInitial(),
                    )
                  : !searched
                  ? _buildIdle(t)
                  : state.searching
                  ? const SizedBox.shrink()
                  : state.results.isEmpty && state.userResults.isEmpty
                  ? _buildNothing(t)
                  : postsTab
                  ? _buildPosts(t, state)
                  : _buildUsers(t, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(ZxTokens t) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: t.bgSunk,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, size: 19, color: t.text3),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              key: const Key('mobile-search-field'),
              controller: _query,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              style: ZxType.body.copyWith(color: t.text),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                hintText: '搜索帖子、用户或 #话题',
                hintStyle: ZxType.body.copyWith(color: t.text3),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_query.text.isNotEmpty)
            IconButton(
              tooltip: '清空',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: t.text3),
              onPressed: () {
                _query.clear();
                _focus.requestFocus();
              },
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  /// Before any search: the topics to start from.
  Widget _buildIdle(ZxTokens t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          '试试这些话题',
          style: ZxType.caption.copyWith(
            color: t.text3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _topicChips(t, alignStart: true),
      ],
    );
  }

  /// Handoff S3: nothing in either tab.
  Widget _buildNothing(ZxTokens t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: t.primarySoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.primary.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.search_rounded, size: 30, color: t.primary),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          '没有找到「$_submitted」\n相关的内容',
          textAlign: TextAlign.center,
          style: ZxType.headline.copyWith(
            fontSize: 20,
            height: 1.5,
            color: t.text,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '换个关键词，或看看这些话题',
          textAlign: TextAlign.center,
          style: ZxType.body.copyWith(color: t.text2),
        ),
        const SizedBox(height: 20),
        _topicChips(t),
      ],
    );
  }

  Widget _topicChips(ZxTokens t, {bool alignStart = false}) {
    final List<String> topics = _topics.isEmpty ? _fallbackTopics : _topics;
    return Wrap(
      alignment: alignStart ? WrapAlignment.start : WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final String topic in topics)
          Material(
            color: t.surface,
            shape: StadiumBorder(side: BorderSide(color: t.line)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => _submit('#$topic'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  '#$topic',
                  style: ZxType.label.copyWith(fontSize: 13, color: t.primary),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPosts(ZxTokens t, SearchState state) {
    final notifier = ref.read(searchControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (_isTopic) _topicCard(t, state),
        if (state.results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              '没有找到相关帖子',
              textAlign: TextAlign.center,
              style: ZxType.body.copyWith(color: t.text3),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(top: BorderSide(color: t.line)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < state.results.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: t.line),
                  PostCard(
                    key: ValueKey<String>(state.results[i].id),
                    post: state.results[i],
                    highlight: state.keyword,
                    onTap: () => context.push('/post/${state.results[i].id}'),
                    onLike: () =>
                        _act(() => notifier.toggleLike(state.results[i])),
                    onFavorite: () =>
                        _act(() => notifier.toggleFavorite(state.results[i])),
                    onAuthorTap:
                        state.results[i].canViewAuthorProfile &&
                            state.results[i].authorUserId.isNotEmpty
                        ? () => context.push(
                            '/user/${state.results[i].authorUserId}',
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// Handoff S1: the topic's name, size and freshness, with its sort.
  Widget _topicCard(ZxTokens t, SearchState state) {
    final String name = _submitted.substring(1).trim();
    DateTime? latest;
    for (final PostItem post in state.results) {
      if (latest == null || post.createdAt.isAfter(latest)) {
        latest = post.createdAt;
      }
    }
    final String meta = latest == null
        ? '${state.results.length} 条帖子'
        : '${state.results.length} 条帖子 · 最近 ${formatRelativeTime(latest)}';
    return Container(
      key: const Key('mobile-search-topic'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: t.heroGradient,
        ),
        borderRadius: ZxRadius.cardAll,
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#',
              style: ZxType.title.copyWith(
                fontSize: 22,
                color: t.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: ZxType.headline.copyWith(fontSize: 20, color: t.text),
                ),
                const SizedBox(height: 2),
                Text(meta, style: ZxType.caption.copyWith(color: t.text3)),
              ],
            ),
          ),
          _SortToggle(
            value: state.sort,
            enabled: !state.searching,
            onChanged: (PostSort sort) =>
                ref.read(searchControllerProvider.notifier).updateSort(sort),
          ),
        ],
      ),
    );
  }

  Widget _buildUsers(ZxTokens t, SearchState state) {
    if (state.userResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Text(
          '没有找到相关用户\n只显示实名账号，匿名昵称不参与用户搜索',
          textAlign: TextAlign.center,
          style: ZxType.body.copyWith(color: t.text3, height: 1.6),
        ),
      );
    }
    final notifier = ref.read(searchControllerProvider.notifier);
    return ColoredBox(
      color: t.surface,
      child: ListView.separated(
        itemCount: state.userResults.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: t.line),
        itemBuilder: (BuildContext context, int i) {
          final PublicUserProfile user = state.userResults[i];
          return _UserRow(
            user: user,
            keyword: state.keyword,
            onTap: () => context.push('/user/${user.id}'),
            onFollow: user.canFollow
                ? () => _act(() => notifier.toggleFollow(user))
                : null,
          );
        },
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
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
          children: [
            Text(
              label,
              style: ZxType.label.copyWith(
                fontSize: 15,
                color: selected ? t.text : t.text3,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            Text('$count', style: ZxType.caption.copyWith(color: t.text3)),
          ],
        ),
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final PostSort value;
  final bool enabled;
  final ValueChanged<PostSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    Widget option(PostSort sort, String label) {
      final bool on = value == sort;
      return GestureDetector(
        key: Key('mobile-search-sort-${sort.name}'),
        onTap: enabled && !on ? () => onChanged(sort) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? t.surface : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: on ? t.shadow1 : null,
          ),
          child: Text(
            label,
            style: ZxType.caption.copyWith(
              fontSize: 13,
              color: on ? t.primary : t.text3,
              fontWeight: on ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.bgSunk,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option(PostSort.latest, '最新'), option(PostSort.hot, '最热')],
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
    final String college = user.college.trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            ZxAvatar(
              name: name,
              imageUrl: AppConfig.resolveUrl(user.avatarUrl),
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: highlightSpans(
                        name,
                        keyword,
                        TextStyle(color: t.primary),
                      ),
                    ),
                    style: ZxType.label.copyWith(fontSize: 15, color: t.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (college.isNotEmpty) college,
                      '${user.postCount} 帖子',
                      '${user.followerCount} 粉丝',
                    ].join(' · '),
                    style: ZxType.caption.copyWith(color: t.text3),
                  ),
                ],
              ),
            ),
            if (onFollow != null)
              ZxButton(
                label: mutual
                    ? '互相关注'
                    : user.isFollowing
                    ? '已关注'
                    : '关注',
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
