import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/mobile_providers.dart';
import '../../features/widgets/shimmer_loading.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'package:xdu_treehole_web/design_system/design_system.dart';
import 'package:xdu_treehole_web/features/feed/feed_controller.dart'
    show FeedState;
import 'package:xdu_treehole_web/widgets/post_card.dart';
import '../shell/mobile_shell.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scrollController = ScrollController();

  /// FAB 是否已隐藏（与底部导航栏同步）
  bool _fabVisible = true;
  double _lastScrollOffset = 0;
  bool _isRefreshing = false;
  bool _showRefreshSuccessFlash = false;
  List<String> _lockedOrderPostIds = const <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedControllerProvider.notifier).loadInitial();
    });
    _scrollController.addListener(_onScroll);
    BottomNavVisibilityNotifier.instance.addListener(_onNavVisibilityChanged);
  }

  void _onNavVisibilityChanged() {
    if (!mounted) return;
    final visible = BottomNavVisibilityNotifier.instance.visible;
    if (_fabVisible != visible) {
      setState(() => _fabVisible = visible);
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  List<PostItem> _postsForDisplay(List<PostItem> posts) {
    if (_lockedOrderPostIds.isEmpty || posts.length <= 1) {
      return posts;
    }

    final Map<String, PostItem> byId = <String, PostItem>{
      for (final post in posts) post.id: post,
    };
    final List<PostItem> ordered = <PostItem>[];

    for (final postId in _lockedOrderPostIds) {
      final post = byId.remove(postId);
      if (post != null) {
        ordered.add(post);
      }
    }

    if (byId.isNotEmpty) {
      for (final post in posts) {
        if (byId.containsKey(post.id)) {
          ordered.add(post);
        }
      }
    }

    return ordered;
  }

  Future<void> _refreshHomeFeed() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    bool refreshSucceeded = false;
    try {
      await ref.read(feedControllerProvider.notifier).refreshPosts();
      refreshSucceeded = ref.read(feedControllerProvider).error == null;
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRefreshing = false;
        _showRefreshSuccessFlash = refreshSucceeded;
      });
      if (refreshSucceeded) {
        await Future<void>.delayed(const Duration(milliseconds: 140));
        if (!mounted) {
          return;
        }
        setState(() {
          _showRefreshSuccessFlash = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次回到首页时恢复底部导航栏可见性
    BottomNavVisibilityNotifier.instance.show();
  }

  @override
  void dispose() {
    BottomNavVisibilityNotifier.instance.removeListener(
      _onNavVisibilityChanged,
    );
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // 懒加载更多
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 200) {
      ref.read(feedControllerProvider.notifier).loadMoreIfNeeded();
    }

    final delta = currentScroll - _lastScrollOffset;

    // 底部导航栏显示/隐藏（任何明显方向性滚动即触发）
    if (delta > 1) {
      BottomNavVisibilityNotifier.instance.hide();
    } else if (delta < -1) {
      BottomNavVisibilityNotifier.instance.show();
    }

    _lastScrollOffset = currentScroll;
  }

  Future<void> _handleLike(PostItem post) async {
    final wasLiked = post.isLiked;
    final optimistic = post.copyWith(
      isLiked: !wasLiked,
      likeCount: post.likeCount + (wasLiked ? -1 : 1),
    );
    ref.read(feedControllerProvider.notifier).replacePost(optimistic);
    try {
      final postRepo = ref.read(postRepositoryProvider);
      if (wasLiked) {
        await postRepo.unlikePost(post.id);
      } else {
        await postRepo.likePost(post.id);
      }
    } catch (_) {
      ref.read(feedControllerProvider.notifier).replacePost(post);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
      }
    }
  }

  Future<void> _handleFavorite(PostItem post) async {
    final bool was = post.isFavorited;
    ref
        .read(feedControllerProvider.notifier)
        .replacePost(
          post.copyWith(
            isFavorited: !was,
            favoriteCount: post.favoriteCount + (was ? -1 : 1),
          ),
        );
    try {
      final postRepo = ref.read(postRepositoryProvider);
      if (was) {
        await postRepo.unfavoritePost(post.id);
      } else {
        await postRepo.favoritePost(post.id);
      }
    } catch (_) {
      ref.read(feedControllerProvider.notifier).replacePost(post);
      if (mounted) zxShowToast(context, '操作失败，请稍后重试');
    }
  }

  Future<void> _pickChannel(FeedState feedState) async {
    final String? channel = await zxShowActionSheet<String>(
      context,
      actions: <ZxSheetAction<String>>[
        for (final String c in feedState.channels)
          ZxSheetAction<String>(
            value: c,
            label: c == feedState.selectedChannel ? '$c  ✓' : c,
          ),
      ],
      cancelLabel: '取消',
    );
    if (channel != null) {
      ref.read(feedControllerProvider.notifier).switchChannel(channel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final feedState = ref.watch(feedControllerProvider);
    final visiblePosts = _postsForDisplay(feedState.posts);
    final bool hot = feedState.sort == PostSort.hot;
    // 监听「滚动到顶部」触发器（必须在 build 中调用，initState 中调用不可靠）
    ref.listen<int>(scrollToTopTriggerProvider, (_, __) {
      _scrollToTop();
    });
    ref.listen<int>(
      feedControllerProvider.select((state) => state.orderVersion),
      (_, __) {
        final posts = ref.read(feedControllerProvider).posts;
        if (!mounted) {
          return;
        }
        setState(() {
          _lockedOrderPostIds = posts
              .map((post) => post.id)
              .toList(growable: false);
        });
      },
    );

    // Handoff A1: 树洞 with the channel pill, sort and search, then posts on a
    // sheet. Notifications moved to the 消息 tab.
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          Positioned.fill(child: ZxHeroWash(child: const SizedBox.expand())),
          RefreshIndicator(
            onRefresh: _refreshHomeFeed,
            color: t.primary,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: t.glass,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  surfaceTintColor: Colors.transparent,
                  toolbarHeight: 60,
                  titleSpacing: 20,
                  systemOverlayStyle: isDarkMode
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark,
                  title: Row(
                    children: [
                      Text(
                        '树洞',
                        style: ZxType.headline.copyWith(color: t.text),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: t.surface,
                        shape: StadiumBorder(side: BorderSide(color: t.line)),
                        child: InkWell(
                          key: const Key('mobile-home-channel'),
                          customBorder: const StadiumBorder(),
                          onTap: () => _pickChannel(feedState),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const ZxAvatar.anonymous(name: '印', size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  feedState.selectedChannel,
                                  style: ZxType.label.copyWith(color: t.text),
                                ),
                                Icon(
                                  Icons.expand_more_rounded,
                                  size: 16,
                                  color: t.text3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      key: const Key('mobile-home-sort'),
                      tooltip: hot ? '按热度' : '按时间',
                      icon: Icon(
                        hot
                            ? Icons.local_fire_department_outlined
                            : Icons.schedule_rounded,
                        size: 22,
                        color: hot ? t.primary : t.text2,
                      ),
                      onPressed: () => ref
                          .read(feedControllerProvider.notifier)
                          .switchSort(hot ? PostSort.latest : PostSort.hot),
                    ),
                    IconButton(
                      tooltip: '搜索',
                      icon: Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: t.text2,
                      ),
                      onPressed: () => context.push('/search'),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      '把今天藏进一枚印章里',
                      style: ZxType.caption.copyWith(color: t.text2),
                    ),
                  ),
                ),
                if (feedState.loading && visiblePosts.isEmpty)
                  const SliverFillRemaining(child: HomePageShimmer())
                else if (feedState.error != null && visiblePosts.isEmpty)
                  SliverFillRemaining(
                    child: ZxStatePanel(
                      icon: Icons.cloud_off_outlined,
                      error: true,
                      title: '加载失败',
                      message: feedState.error!,
                      actionLabel: '重试',
                      onAction: () => ref
                          .read(feedControllerProvider.notifier)
                          .loadInitial(),
                    ),
                  )
                else if (visiblePosts.isEmpty)
                  SliverFillRemaining(
                    child: ZxStatePanel(
                      icon: Icons.forum_outlined,
                      title: '这里还没有帖子',
                      message: '可以切换分区，或发布第一条内容。',
                      actionLabel: '写一条',
                      onAction: () => context.push('/post/create'),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(ZxRadius.sheet),
                        ),
                        border: Border(top: BorderSide(color: t.line)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 6, 0, 100),
                        child: Column(
                          children: [
                            for (int i = 0; i < visiblePosts.length; i++) ...[
                              if (i > 0) Divider(height: 1, color: t.line),
                              PostCard(
                                key: ValueKey(visiblePosts[i].id),
                                post: visiblePosts[i],
                                onTap: () =>
                                    context.push('/post/${visiblePosts[i].id}'),
                                onLike: () => _handleLike(visiblePosts[i]),
                                onFavorite: () =>
                                    _handleFavorite(visiblePosts[i]),
                                onAuthorTap:
                                    visiblePosts[i].authorUserId.isEmpty ||
                                        visiblePosts[i].isAnonymous
                                    ? null
                                    : () => context.push(
                                        '/user/${visiblePosts[i].authorUserId}',
                                      ),
                              ),
                            ],
                            if (feedState.hasMore)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: t.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IgnorePointer(
            ignoring: !_showRefreshSuccessFlash,
            child: AnimatedOpacity(
              opacity: _showRefreshSuccessFlash ? 0.6 : 0,
              duration: const Duration(milliseconds: 90),
              // The page colour, so dark mode does not flash white.
              child: ColoredBox(color: t.bg, child: const SizedBox.expand()),
            ),
          ),
        ],
      ),

      // 写: the seal-style compose button.
      floatingActionButton: AnimatedSlide(
        offset: _fabVisible ? Offset.zero : const Offset(0, 2),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: _fabVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          child: Semantics(
            button: true,
            label: '发帖',
            child: GestureDetector(
              key: const Key('mobile-home-compose'),
              onTap: () => context.push('/post/create'),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: t.primaryGlow,
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const ZxAvatar.anonymous(name: '写', size: 58),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 紧凑型排序 Toggle（用于 AppBar）
// ---------------------------------------------------------------------------
