import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../models/post_item.dart';
import '../../models/section_item.dart';
import '../../repositories/post_repository.dart';
import '../../core/l10n/ui_text.dart';

class FeedState {
  const FeedState({
    this.selectedSectionKey = '',
    this.sort = PostSort.hot,
    this.sections = const <SectionItem>[],
    this.posts = const <PostItem>[],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = false,
    this.orderVersion = 0,
  });

  /// A section's key; empty for 全部.
  final String selectedSectionKey;
  final PostSort sort;
  final List<SectionItem> sections;
  final List<PostItem> posts;
  final bool loading;
  final bool loadingMore;
  final String? error;

  /// The last page loaded.
  final int page;
  final bool hasMore;
  final int orderVersion;

  SectionItem? get selectedSection {
    for (final SectionItem section in sections) {
      if (section.key == selectedSectionKey) return section;
    }
    return null;
  }

  FeedState copyWith({
    String? selectedSectionKey,
    PostSort? sort,
    List<SectionItem>? sections,
    List<PostItem>? posts,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    int? page,
    bool? hasMore,
    int? orderVersion,
  }) {
    return FeedState(
      selectedSectionKey: selectedSectionKey ?? this.selectedSectionKey,
      sort: sort ?? this.sort,
      sections: sections ?? this.sections,
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      orderVersion: orderVersion ?? this.orderVersion,
    );
  }
}

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._ref) : super(const FeedState());

  final Ref _ref;

  /// Bumped by every first-page load, so a slower earlier reply (another
  /// section or sort) cannot overwrite the current one.
  int _generation = 0;

  /// A first-page load is in flight. A pull-to-refresh keeps the list (so
  /// state.loading stays false), and a load-more started meanwhile would take
  /// the new generation and append page N+1 after the fresh page 1.
  bool _reloadingFirstPage = false;

  Future<PostPage> _fetchPage(int page) {
    return _ref
        .read(postRepositoryProvider)
        .fetchPostPage(
          section: state.selectedSection,
          sort: state.sort,
          page: page,
        );
  }

  Future<void> loadInitial() async {
    final int generation = ++_generation;
    _reloadingFirstPage = true;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final (List<SectionItem> sections, PostPage first) = await (
        _ref.read(postRepositoryProvider).fetchSections(),
        _fetchPage(1),
      ).wait;
      if (generation != _generation) return;
      state = state.copyWith(sections: sections);
      _showFirstPage(first);
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: uiTextGlobal(zh: '加载失败：$error', en: 'Load failed: $error'),
      );
    } finally {
      if (generation == _generation) _reloadingFirstPage = false;
    }
  }

  Future<void> refreshPosts() => _reload(keepListWhileLoading: true);

  /// [key] is a section's key, or empty for 全部.
  Future<void> switchSection(String key) {
    state = state.copyWith(selectedSectionKey: key);
    return _reload();
  }

  Future<void> switchSort(PostSort sort) {
    state = state.copyWith(sort: sort);
    return _reload();
  }

  Future<void> _reload({bool keepListWhileLoading = false}) async {
    final int generation = ++_generation;
    _reloadingFirstPage = true;
    if (!keepListWhileLoading) {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final PostPage first = await _fetchPage(1);
      if (generation != _generation) return;
      _showFirstPage(first);
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        loading: false,
        // A load-more cut short by this reload never cleared its flag.
        loadingMore: false,
        error: keepListWhileLoading
            ? uiTextGlobal(zh: '刷新失败：$error', en: 'Refresh failed: $error')
            : uiTextGlobal(zh: '加载失败：$error', en: 'Load failed: $error'),
      );
    } finally {
      if (generation == _generation) _reloadingFirstPage = false;
    }
  }

  void _showFirstPage(PostPage first) {
    state = state.copyWith(
      posts: first.items,
      loading: false,
      loadingMore: false,
      clearError: true,
      page: 1,
      hasMore: first.hasMore,
      orderVersion: state.orderVersion + 1,
    );
  }

  Future<void> toggleLike(PostItem post) async {
    final PostRepository posts = _ref.read(postRepositoryProvider);
    final LikeActionResult result = post.isLiked
        ? await posts.unlikePost(post.id)
        : await posts.likePost(post.id);
    replacePost(
      post.copyWith(isLiked: result.liked, likeCount: result.likeCount),
    );
  }

  Future<void> toggleFavorite(PostItem post) async {
    final FavoriteActionResult result = post.isFavorited
        ? await _ref.read(postRepositoryProvider).unfavoritePost(post.id)
        : await _ref.read(postRepositoryProvider).favoritePost(post.id);
    replacePost(
      post.copyWith(
        isFavorited: result.favorited,
        favoriteCount: result.favoriteCount,
      ),
    );
  }

  Future<void> loadMoreIfNeeded() async {
    if (state.loadingMore ||
        !state.hasMore ||
        state.loading ||
        _reloadingFirstPage) {
      return;
    }
    final int generation = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final int nextPage = state.page + 1;
      final PostPage more = await _fetchPage(nextPage);
      if (generation != _generation) return;
      // A post published meanwhile shifts the pages by one; skip repeats.
      final Set<String> seen = state.posts.map((PostItem p) => p.id).toSet();
      state = state.copyWith(
        posts: <PostItem>[
          ...state.posts,
          ...more.items.where((PostItem p) => seen.add(p.id)),
        ],
        loadingMore: false,
        page: nextPage,
        hasMore: more.hasMore,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        loadingMore: false,
        error: uiTextGlobal(
          zh: '加载更多失败：$error',
          en: 'Could not load more: $error',
        ),
      );
    }
  }

  void replacePost(PostItem updated) {
    final int index = state.posts.indexWhere(
      (PostItem item) => item.id == updated.id,
    );
    if (index < 0) {
      return;
    }
    final List<PostItem> posts = List<PostItem>.from(state.posts);
    posts[index] = updated;
    state = state.copyWith(
      // Keep the current visual order stable for optimistic updates such as
      // like/favorite toggles. We only recompute sort order on explicit loads.
      posts: posts,
      clearError: true,
    );
  }
}

final feedControllerProvider = StateNotifierProvider<FeedController, FeedState>(
  (Ref ref) {
    ref.watch(accountEpochProvider);
    return FeedController(ref);
  },
);
