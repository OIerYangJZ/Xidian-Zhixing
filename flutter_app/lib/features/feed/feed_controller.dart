import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';

class FeedState {
  const FeedState({
    this.selectedChannel = '全部',
    this.selectedSectionId,
    this.sort = PostSort.hot,
    this.channels = const <String>['全部'],
    this.collegeSections = const <ForumSection>[],
    this.posts = const <PostItem>[],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = false,
    this.orderVersion = 0,
  });

  final String selectedChannel;
  final String? selectedSectionId;
  final PostSort sort;
  final List<String> channels;
  final List<ForumSection> collegeSections;
  final List<PostItem> posts;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final int page;
  final bool hasMore;
  final int orderVersion;

  FeedState copyWith({
    String? selectedChannel,
    String? selectedSectionId,
    bool clearSelectedSection = false,
    PostSort? sort,
    List<String>? channels,
    List<ForumSection>? collegeSections,
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
      selectedChannel: selectedChannel ?? this.selectedChannel,
      selectedSectionId: clearSelectedSection
          ? null
          : (selectedSectionId ?? this.selectedSectionId),
      sort: sort ?? this.sort,
      channels: channels ?? this.channels,
      collegeSections: collegeSections ?? this.collegeSections,
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

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final PostRepository repository = _ref.read(postRepositoryProvider);
      final results = await Future.wait<Object>(<Future<Object>>[
        repository.fetchChannels(),
        repository.fetchPosts(sort: state.sort),
        repository.fetchCollegeSections(),
      ]);
      final List<String> channels = results[0] as List<String>;
      final List<PostItem> posts = results[1] as List<PostItem>;
      final List<ForumSection> collegeSections =
          results[2] as List<ForumSection>;
      state = state.copyWith(
        channels: <String>['全部', ...channels.toSet().where((c) => c != '其他')],
        collegeSections: collegeSections,
        posts: sortPostsForView(posts, sort: state.sort),
        loading: false,
        clearError: true,
        page: 1,
        hasMore: posts.length >= 20,
        orderVersion: state.orderVersion + 1,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '加载失败：$error');
    }
  }

  Future<void> refreshPosts() async {
    try {
      final List<PostItem> posts = await _fetchPostsForSelection(
        _ref.read(postRepositoryProvider),
        sort: state.sort,
      );
      state = state.copyWith(
        posts: sortPostsForView(posts, sort: state.sort),
        clearError: true,
        page: 1,
        hasMore: posts.length >= 20,
        orderVersion: state.orderVersion + 1,
      );
    } catch (error) {
      state = state.copyWith(error: '刷新失败：$error');
    }
  }

  Future<void> switchChannel(String channel) async {
    state = state.copyWith(
      selectedChannel: channel,
      clearSelectedSection: true,
      loading: true,
      clearError: true,
    );
    try {
      final List<PostItem> posts = await _fetchPostsForSelection(
        _ref.read(postRepositoryProvider),
        selectedChannel: channel,
        clearSelectedSection: true,
        sort: state.sort,
      );
      state = state.copyWith(
        posts: sortPostsForView(posts, sort: state.sort),
        loading: false,
        clearError: true,
        page: 1,
        hasMore: posts.length >= 20,
        orderVersion: state.orderVersion + 1,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '加载失败：$error');
    }
  }

  Future<void> switchCollegeSection(ForumSection section) async {
    state = state.copyWith(
      selectedChannel: section.name,
      selectedSectionId: section.id,
      loading: true,
      clearError: true,
    );
    try {
      final List<PostItem> posts = await _fetchPostsForSelection(
        _ref.read(postRepositoryProvider),
        selectedChannel: section.name,
        selectedSectionId: section.id,
        sort: state.sort,
      );
      state = state.copyWith(
        posts: sortPostsForView(posts, sort: state.sort),
        loading: false,
        clearError: true,
        page: 1,
        hasMore: posts.length >= 20,
        orderVersion: state.orderVersion + 1,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '加载失败：$error');
    }
  }

  Future<void> switchSort(PostSort sort) async {
    state = state.copyWith(sort: sort, loading: true, clearError: true);
    try {
      final List<PostItem> posts = await _fetchPostsForSelection(
        _ref.read(postRepositoryProvider),
        sort: sort,
      );
      state = state.copyWith(
        posts: sortPostsForView(posts, sort: sort),
        loading: false,
        clearError: true,
        page: 1,
        hasMore: posts.length >= 20,
        orderVersion: state.orderVersion + 1,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '排序切换失败：$error');
    }
  }

  Future<void> toggleLike(PostItem post) async {
    final bool nextLiked = !post.isLiked;
    if (nextLiked) {
      await _ref.read(postRepositoryProvider).likePost(post.id);
    } else {
      await _ref.read(postRepositoryProvider).unlikePost(post.id);
    }
    final int nextCount = (post.likeCount + (nextLiked ? 1 : -1)).clamp(
      0,
      1 << 31,
    );
    replacePost(post.copyWith(isLiked: nextLiked, likeCount: nextCount));
  }

  Future<void> toggleFavorite(PostItem post) async {
    final FavoriteActionResult result = post.isFavorited
        ? await _ref.read(postRepositoryProvider).unfavoritePost(post.id)
        : await _ref.read(postRepositoryProvider).favoritePost(post.id);
    replacePost(
      post.copyWith(
        isFavorited: result.favorited,
        favoriteCount:
            result.favoriteCount ??
            (post.favoriteCount + (result.favorited ? 1 : -1)).clamp(
              0,
              1 << 31,
            ),
      ),
    );
  }

  Future<void> loadMoreIfNeeded() async {
    if (state.loadingMore || !state.hasMore || state.loading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final nextPage = state.page + 1;
      final List<PostItem> morePosts = await _fetchPostsForSelection(
        _ref.read(postRepositoryProvider),
        sort: state.sort,
      );
      final Set<String> existingIds = state.posts
          .map((PostItem item) => item.id)
          .toSet();
      final List<PostItem> uniqueMorePosts = morePosts
          .where((PostItem item) => existingIds.add(item.id))
          .toList(growable: false);
      state = state.copyWith(
        posts: sortPostsForView(<PostItem>[
          ...state.posts,
          ...uniqueMorePosts,
        ], sort: state.sort),
        loadingMore: false,
        page: nextPage,
        hasMore: morePosts.length >= 20 && uniqueMorePosts.isNotEmpty,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
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

  Future<List<PostItem>> _fetchPostsForSelection(
    PostRepository repository, {
    String? selectedChannel,
    String? selectedSectionId,
    bool clearSelectedSection = false,
    required PostSort sort,
  }) {
    final String? sectionId = clearSelectedSection
        ? null
        : (selectedSectionId ?? state.selectedSectionId);
    if (sectionId != null) {
      return repository.fetchSectionPosts(sectionId: sectionId, sort: sort);
    }
    final String channel = selectedChannel ?? state.selectedChannel;
    return repository.fetchPosts(
      channel: channel == '全部' ? null : channel,
      sort: sort,
    );
  }
}

final feedControllerProvider = StateNotifierProvider<FeedController, FeedState>(
  (Ref ref) => FeedController(ref),
);
