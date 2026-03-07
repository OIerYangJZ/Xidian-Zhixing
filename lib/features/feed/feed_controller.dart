import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';

class FeedState {
  const FeedState({
    this.selectedChannel = '全部',
    this.sort = PostSort.latest,
    this.channels = const <String>['全部'],
    this.posts = const <PostItem>[],
    this.loading = true,
    this.error,
  });

  final String selectedChannel;
  final PostSort sort;
  final List<String> channels;
  final List<PostItem> posts;
  final bool loading;
  final String? error;

  FeedState copyWith({
    String? selectedChannel,
    PostSort? sort,
    List<String>? channels,
    List<PostItem>? posts,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return FeedState(
      selectedChannel: selectedChannel ?? this.selectedChannel,
      sort: sort ?? this.sort,
      channels: channels ?? this.channels,
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._ref) : super(const FeedState());

  final Ref _ref;

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final List<String> channels =
          await _ref.read(postRepositoryProvider).fetchChannels();
      final List<PostItem> posts =
          await _ref.read(postRepositoryProvider).fetchPosts(
                sort: state.sort,
              );
      state = state.copyWith(
        channels: <String>['全部', ...channels.toSet()],
        posts: posts,
        loading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: '加载失败：$error',
      );
    }
  }

  Future<void> refreshPosts() async {
    try {
      final List<PostItem> posts =
          await _ref.read(postRepositoryProvider).fetchPosts(
                channel: state.selectedChannel == '全部'
                    ? null
                    : state.selectedChannel,
                sort: state.sort,
              );
      state = state.copyWith(posts: posts, clearError: true);
    } catch (error) {
      state = state.copyWith(error: '刷新失败：$error');
    }
  }

  Future<void> switchChannel(String channel) async {
    state = state.copyWith(
      selectedChannel: channel,
      loading: true,
      clearError: true,
    );
    try {
      final List<PostItem> posts =
          await _ref.read(postRepositoryProvider).fetchPosts(
                channel: channel == '全部' ? null : channel,
                sort: state.sort,
              );
      state = state.copyWith(posts: posts, loading: false, clearError: true);
    } catch (error) {
      state = state.copyWith(loading: false, error: '加载失败：$error');
    }
  }

  Future<void> switchSort(PostSort sort) async {
    state = state.copyWith(
      sort: sort,
      loading: true,
      clearError: true,
    );
    try {
      final List<PostItem> posts =
          await _ref.read(postRepositoryProvider).fetchPosts(
                channel: state.selectedChannel == '全部'
                    ? null
                    : state.selectedChannel,
                sort: sort,
              );
      state = state.copyWith(
        posts: posts,
        loading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: '排序切换失败：$error',
      );
    }
  }
}

final feedControllerProvider = StateNotifierProvider<FeedController, FeedState>(
  (Ref ref) => FeedController(ref),
);
