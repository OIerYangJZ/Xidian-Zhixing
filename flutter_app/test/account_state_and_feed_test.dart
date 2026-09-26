import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/design_system/zx_metrics.dart';
import 'package:xdu_treehole_web/features/feed/feed_controller.dart';
import 'package:xdu_treehole_web/features/messages/messages_controller.dart';
import 'package:xdu_treehole_web/features/notifications/notifications_controller.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/models/section_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';

PostItem _post(String id) => PostItem.fromJson(<String, dynamic>{
  'id': id,
  'title': id,
  'content': id,
  'tags': <String>[],
  'authorAlias': '同学',
  'createdAt': '2026-09-26T00:00:00+00:00',
  'hasImage': false,
  'commentCount': 0,
  'likeCount': 0,
  'favoriteCount': 0,
  'status': 'ongoing',
  'allowComment': true,
  'allowDm': false,
});

/// Pages answer only when the test completes them, in any order.
class _ManualPosts extends PostRepository {
  _ManualPosts() : super(ApiClient());

  final List<(int, Completer<PostPage>)> pending =
      <(int, Completer<PostPage>)>[];

  @override
  Future<List<SectionItem>> fetchSections() async => const <SectionItem>[];

  @override
  Future<PostPage> fetchPostPage({
    SectionItem? section,
    PostSort sort = PostSort.latest,
    required int page,
    int limit = postPageSize,
  }) {
    final Completer<PostPage> completer = Completer<PostPage>();
    pending.add((page, completer));
    return completer.future;
  }

  void answer(int page, List<String> ids, {bool hasMore = true}) {
    final int index = pending.indexWhere(
      ((int, Completer<PostPage>) p) => p.$1 == page,
    );
    final Completer<PostPage> completer = pending.removeAt(index).$2;
    completer.complete(
      PostPage(items: ids.map(_post).toList(), hasMore: hasMore),
    );
  }
}

void main() {
  test('a new account starts from empty per-account state', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final FeedController feed = container.read(feedControllerProvider.notifier);
    final MessagesController messages = container.read(
      messagesControllerProvider.notifier,
    );
    final NotificationsController notifications = container.read(
      notificationsControllerProvider.notifier,
    );

    await AuthStore.instance.saveToken('account-b');
    addTearDown(AuthStore.instance.clear);

    expect(container.read(feedControllerProvider.notifier), isNot(same(feed)));
    expect(
      container.read(messagesControllerProvider.notifier),
      isNot(same(messages)),
    );
    expect(
      container.read(notificationsControllerProvider.notifier),
      isNot(same(notifications)),
    );

    // Signing out resets them again.
    final FeedController signedIn = container.read(
      feedControllerProvider.notifier,
    );
    await AuthStore.instance.clear();
    expect(
      container.read(feedControllerProvider.notifier),
      isNot(same(signedIn)),
    );
  });

  test('the rare-hanzi font loads from the site root and retries', () async {
    final List<Uri> asked = <Uri>[];
    ZxFonts.debugFetchFont = (Uri url) async {
      asked.add(url);
      throw StateError('HTTP 404');
    };
    addTearDown(() {
      ZxFonts.debugResetDeferred();
    });
    ZxFonts.debugResetDeferred();

    await ZxFonts.loadRareFont();
    // Not /p/fonts/… when the page was opened from a share link.
    expect(asked.single.path, '/fonts/STSong-Rare.ttf');

    // A failure is not remembered: the next build asks again.
    await ZxFonts.loadRareFont();
    expect(asked, hasLength(2));
  });

  test('a load-more during a pull-to-refresh leaves no gap', () async {
    final _ManualPosts posts = _ManualPosts();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[postRepositoryProvider.overrideWithValue(posts)],
    );
    addTearDown(container.dispose);
    final FeedController feed = container.read(feedControllerProvider.notifier);

    final Future<void> initial = feed.loadInitial();
    await Future<void>.delayed(Duration.zero);
    posts.answer(1, <String>['a', 'b']);
    await initial;
    final Future<void> more = feed.loadMoreIfNeeded();
    await Future<void>.delayed(Duration.zero);
    posts.answer(2, <String>['c', 'd']);
    await more;
    expect(container.read(feedControllerProvider).page, 2);

    // Refresh keeps the list on screen; a load-more meanwhile must wait.
    final Future<void> refresh = feed.refreshPosts();
    await feed.loadMoreIfNeeded();
    expect(posts.pending.map(((int, Completer<PostPage>) p) => p.$1), <int>[1]);

    posts.answer(1, <String>['new', 'a']);
    await refresh;
    final FeedState state = container.read(feedControllerProvider);
    expect(state.page, 1);
    expect(state.posts.map((PostItem p) => p.id), <String>['new', 'a']);
    expect(state.loadingMore, isFalse);
  });
}
