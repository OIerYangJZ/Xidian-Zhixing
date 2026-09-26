import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../models/post_item.dart';
import '../../models/public_user_profile.dart';
import '../../models/section_item.dart';
import '../../repositories/post_repository.dart';
import '../../core/l10n/ui_text.dart';

enum SearchResultTab { posts, users }

class SearchState {
  const SearchState({
    this.sections = const <SectionItem>[],
    this.selectedSectionKey = '',
    this.keyword = '',
    this.sort = PostSort.latest,
    this.results = const <PostItem>[],
    this.userResults = const <PublicUserProfile>[],
    this.selectedTab = SearchResultTab.posts,
    this.loading = true,
    this.searching = false,
    this.error,
  });

  final List<SectionItem> sections;

  /// A section's key; empty for 全部.
  final String selectedSectionKey;

  SectionItem? get selectedSection {
    for (final SectionItem section in sections) {
      if (section.key == selectedSectionKey) return section;
    }
    return null;
  }

  final String keyword;
  final PostSort sort;
  final List<PostItem> results;
  final List<PublicUserProfile> userResults;
  final SearchResultTab selectedTab;
  final bool loading;
  final bool searching;
  final String? error;

  SearchState copyWith({
    List<SectionItem>? sections,
    String? selectedSectionKey,
    String? keyword,
    PostSort? sort,
    List<PostItem>? results,
    List<PublicUserProfile>? userResults,
    SearchResultTab? selectedTab,
    bool? loading,
    bool? searching,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      sections: sections ?? this.sections,
      selectedSectionKey: selectedSectionKey ?? this.selectedSectionKey,
      keyword: keyword ?? this.keyword,
      sort: sort ?? this.sort,
      results: results ?? this.results,
      userResults: userResults ?? this.userResults,
      selectedTab: selectedTab ?? this.selectedTab,
      loading: loading ?? this.loading,
      searching: searching ?? this.searching,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SearchController extends StateNotifier<SearchState> {
  SearchController(this._ref) : super(const SearchState());

  final Ref _ref;
  int _requestSequence = 0;

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true, searching: false, clearError: true);
    final int requestId = ++_requestSequence;
    try {
      final List<SectionItem> sections = await _ref
          .read(postRepositoryProvider)
          .fetchSections();
      if (requestId != _requestSequence) {
        return;
      }
      state = state.copyWith(
        sections: sections,
        selectedSectionKey:
            sections.any((SectionItem s) => s.key == state.selectedSectionKey)
            ? state.selectedSectionKey
            : '',
        loading: false,
        clearError: true,
      );
      await search();
    } catch (error) {
      if (requestId != _requestSequence) {
        return;
      }
      state = state.copyWith(
        loading: false,
        searching: false,
        error: uiTextGlobal(
          zh: '分区加载失败：$error',
          en: 'Could not load sections: $error',
        ),
      );
    }
  }

  void setKeyword(String keyword) {
    state = state.copyWith(keyword: keyword);
  }

  /// [key] is a section's key, or empty for 全部.
  Future<void> updateSection(String key) async {
    state = state.copyWith(selectedSectionKey: key);
    await search();
  }

  Future<void> updateSort(PostSort value) async {
    state = state.copyWith(sort: value);
    await search();
  }

  void updateTab(SearchResultTab value) {
    state = state.copyWith(selectedTab: value, clearError: true);
  }

  Future<void> search() async {
    state = state.copyWith(searching: true, clearError: true);
    final int requestId = ++_requestSequence;
    try {
      final String normalizedKeyword = state.keyword.trim();
      final List<dynamic>
      results = await Future.wait<dynamic>(<Future<dynamic>>[
        _ref
            .read(postRepositoryProvider)
            .fetchPosts(
              section: state.selectedSection,
              keyword: normalizedKeyword.isEmpty ? null : normalizedKeyword,
              sort: state.sort,
            ),
        normalizedKeyword.isEmpty
            ? Future<List<PublicUserProfile>>.value(const <PublicUserProfile>[])
            : _ref.read(userRepositoryProvider).searchUsers(normalizedKeyword),
      ]);

      if (requestId != _requestSequence) {
        return;
      }
      state = state.copyWith(
        results: results[0] as List<PostItem>,
        userResults: results[1] as List<PublicUserProfile>,
        loading: false,
        searching: false,
        clearError: true,
      );
    } catch (error) {
      if (requestId != _requestSequence) {
        return;
      }
      state = state.copyWith(
        loading: false,
        searching: false,
        error: uiTextGlobal(zh: '搜索失败：$error', en: 'Search failed: $error'),
      );
    }
  }

  Future<void> toggleLike(PostItem post) async {
    final PostRepository posts = _ref.read(postRepositoryProvider);
    final LikeActionResult result = post.isLiked
        ? await posts.unlikePost(post.id)
        : await posts.likePost(post.id);
    replaceResult(
      post.copyWith(isLiked: result.liked, likeCount: result.likeCount),
    );
  }

  Future<void> toggleFavorite(PostItem post) async {
    final FavoriteActionResult result = post.isFavorited
        ? await _ref.read(postRepositoryProvider).unfavoritePost(post.id)
        : await _ref.read(postRepositoryProvider).favoritePost(post.id);
    replaceResult(
      post.copyWith(
        isFavorited: result.favorited,
        favoriteCount: result.favoriteCount,
      ),
    );
  }

  Future<void> toggleFollow(PublicUserProfile user) async {
    final bool following = !user.isFollowing;
    if (following) {
      await _ref.read(userRepositoryProvider).followUser(user.id);
    } else {
      await _ref.read(userRepositoryProvider).unfollowUser(user.id);
    }
    state = state.copyWith(
      userResults: <PublicUserProfile>[
        for (final PublicUserProfile item in state.userResults)
          item.id == user.id
              ? item.copyWith(
                  isFollowing: following,
                  followerCount: (item.followerCount + (following ? 1 : -1))
                      .clamp(0, 1 << 31),
                )
              : item,
      ],
    );
  }

  void replaceResult(PostItem updated) {
    final int index = state.results.indexWhere(
      (PostItem item) => item.id == updated.id,
    );
    if (index < 0) {
      return;
    }
    final List<PostItem> results = List<PostItem>.from(state.results);
    results[index] = updated;
    state = state.copyWith(
      results: sortPostsForView(results, sort: state.sort),
      clearError: true,
    );
  }
}

final searchControllerProvider =
    StateNotifierProvider.autoDispose<SearchController, SearchState>((Ref ref) {
      ref.watch(accountEpochProvider);
      return SearchController(ref);
    });
