import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/navigation/post_detail_nav.dart';
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
      appBar: AppBar(
        title: Text(uiText(context, zh: '搜索', en: 'Search')),
      ),
      body: AsyncPageState(
        loading: state.loading,
        error: state.error,
        onRetry: () =>
            ref.read(searchControllerProvider.notifier).loadInitial(),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            TextField(
              controller: _queryController,
              autofocus: widget.autofocus,
              decoration: InputDecoration(
                hintText: uiText(
                  context,
                  zh: '输入关键词搜索帖子，或按昵称搜索用户',
                  en: 'Search posts by keyword or users by nickname',
                ),
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => _submitSearch(),
            ),
            const SizedBox(height: 10),
            SegmentedButton<SearchResultTab>(
              segments: <ButtonSegment<SearchResultTab>>[
                ButtonSegment<SearchResultTab>(
                  value: SearchResultTab.posts,
                  label: Text(
                    uiText(
                      context,
                      zh: '帖子 ${state.results.length}',
                      en: 'Posts ${state.results.length}',
                    ),
                  ),
                  icon: const Icon(Icons.article_outlined),
                ),
                ButtonSegment<SearchResultTab>(
                  value: SearchResultTab.users,
                  label: Text(
                    uiText(
                      context,
                      zh: '用户 ${state.userResults.length}',
                      en: 'Users ${state.userResults.length}',
                    ),
                  ),
                  icon: const Icon(Icons.person_search_outlined),
                ),
              ],
              selected: <SearchResultTab>{state.selectedTab},
              onSelectionChanged: (Set<SearchResultTab> value) {
                ref
                    .read(searchControllerProvider.notifier)
                    .updateTab(value.first);
              },
            ),
            const SizedBox(height: 10),
            if (state.selectedTab == SearchResultTab.posts) ...<Widget>[
              _buildPostFilters(state),
              const SizedBox(height: 10),
              if (state.searching)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              Text(
                uiText(
                  context,
                  zh: '共找到 ${state.results.length} 条帖子',
                  en: '${state.results.length} posts found',
                ),
              ),
              const SizedBox(height: 6),
              ...state.results.map(
                (PostItem post) => PostCard(
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
                        .read(searchControllerProvider.notifier)
                        .replaceResult(updated);
                  },
                ),
              ),
              if (state.results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      uiText(
                        context,
                        zh: '没有匹配帖子，换个关键词试试。',
                        en: 'No matching posts. Try another keyword.',
                      ),
                    ),
                  ),
                ),
            ] else ...<Widget>[
              _buildUserSearchActions(state),
              const SizedBox(height: 10),
              if (state.searching)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              Text(
                uiText(
                  context,
                  zh: '共找到 ${state.userResults.length} 位用户',
                  en: '${state.userResults.length} users found',
                ),
              ),
              const SizedBox(height: 6),
              if (state.keyword.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      uiText(
                        context,
                        zh: '输入昵称后即可搜索用户。',
                        en: 'Enter a nickname to search for users.',
                      ),
                    ),
                  ),
                )
              else ...<Widget>[
                ...state.userResults.map(_buildUserCard),
                if (state.userResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        uiText(
                          context,
                          zh: '没有找到匹配昵称的用户。',
                          en: 'No users match that nickname.',
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPostFilters(SearchState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            initialValue: state.selectedChannel,
            decoration: InputDecoration(
              labelText: uiText(context, zh: '频道', en: 'Channel'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
            items: state.channels
                .map(
                  (String c) =>
                      DropdownMenuItem<String>(value: c, child: Text(c)),
                )
                .toList(),
            onChanged: state.searching
                ? null
                : (String? value) {
                    if (value == null) {
                      return;
                    }
                    ref
                        .read(searchControllerProvider.notifier)
                        .updateChannel(value);
                  },
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<PostStatus?>(
            initialValue: state.status,
            decoration: InputDecoration(
              labelText: uiText(context, zh: '状态', en: 'Status'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
            items: <DropdownMenuItem<PostStatus?>>[
              DropdownMenuItem<PostStatus?>(
                value: null,
                child: Text(uiText(context, zh: '全部状态', en: 'All statuses')),
              ),
              ...PostStatus.values.map(
                (PostStatus status) => DropdownMenuItem<PostStatus?>(
                  value: status,
                  child: Text(status.label),
                ),
              ),
            ],
            onChanged: state.searching
                ? null
                : (PostStatus? value) {
                    ref
                        .read(searchControllerProvider.notifier)
                        .updateStatus(value);
                  },
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<PostSort>(
            initialValue: state.sort,
            decoration: InputDecoration(
              labelText: uiText(context, zh: '排序', en: 'Sort'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
            items: _webSorts
                .map(
                  (PostSort value) => DropdownMenuItem<PostSort>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(),
            onChanged: state.searching
                ? null
                : (PostSort? value) {
                    if (value == null) {
                      return;
                    }
                    ref
                        .read(searchControllerProvider.notifier)
                        .updateSort(value);
                  },
          ),
        ),
        FilterChip(
          label: Text(uiText(context, zh: '仅看有图', en: 'With images')),
          selected: state.imageOnly,
          onSelected: state.searching
              ? null
              : (bool selected) {
                  ref
                      .read(searchControllerProvider.notifier)
                      .updateImageOnly(selected);
                },
        ),
        FilterChip(
          label: Text(uiText(context, zh: '仅看可私信', en: 'Messageable')),
          selected: state.dmOnly,
          onSelected: state.searching
              ? null
              : (bool selected) {
                  ref
                      .read(searchControllerProvider.notifier)
                      .updateDmOnly(selected);
                },
        ),
        FilledButton.icon(
          onPressed: state.searching ? null : _submitSearch,
          icon: const Icon(Icons.search),
          label: Text(uiText(context, zh: '搜索', en: 'Search')),
        ),
      ],
    );
  }

  Widget _buildUserSearchActions(SearchState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Chip(
          avatar: const Icon(Icons.person_search_outlined, size: 16),
          label: Text(
            uiText(context, zh: '按昵称搜索用户', en: 'Search users by nickname'),
          ),
        ),
        FilledButton.icon(
          onPressed: state.searching ? null : _submitSearch,
          icon: const Icon(Icons.search),
          label: Text(uiText(context, zh: '搜索用户', en: 'Search users')),
        ),
      ],
    );
  }

  Widget _buildUserCard(PublicUserProfile profile) {
    final String resolvedAvatar = AppConfig.resolveUrl(profile.avatarUrl);
    final String fallback = profile.nickname.trim().isEmpty
        ? '?'
        : profile.nickname.trim().substring(0, 1);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          backgroundImage: resolvedAvatar.isNotEmpty
              ? NetworkImage(resolvedAvatar)
              : null,
          child: resolvedAvatar.isEmpty ? Text(fallback) : null,
        ),
        title: Text(profile.nickname),
        subtitle: Text(
          uiText(
            context,
            zh: '${profile.userLevelLabel} · 帖子 ${profile.postCount} · 粉丝 ${profile.followerCount}',
            en: '${profile.postCount} posts · ${profile.followerCount} followers',
          ),
        ),
        trailing: profile.isFollowing
            ? Chip(
                label: Text(uiText(context, zh: '已关注', en: 'Following')),
                visualDensity: VisualDensity.compact,
              )
            : null,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PublicUserProfilePage(userId: profile.id),
            ),
          );
        },
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
