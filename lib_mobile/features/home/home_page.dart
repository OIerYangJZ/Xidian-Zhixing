import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../features/widgets/shimmer_loading.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/features/feed/feed_controller.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'post_card.dart';

/// 每个频道对应的图标和颜色
final _channelMeta = {
  '全部': const _ChannelMeta(Icons.grid_view_rounded, MobileTheme.textSecondary),
  '学习': const _ChannelMeta(Icons.menu_book_rounded, Color(0xFF5E8FD4)),
  '二手': const _ChannelMeta(Icons.sell_rounded, Color(0xFF5EAF7C)),
  '找搭子': const _ChannelMeta(Icons.people_rounded, Color(0xFFE09C5E)),
  '失物': const _ChannelMeta(Icons.search_rounded, Color(0xFFD45E8A)),
  '吐槽': const _ChannelMeta(Icons.chat_bubble_rounded, Color(0xFF9B6ED4)),
  '租房': const _ChannelMeta(Icons.home_rounded, Color(0xFF5EC4AF)),
  '问答': const _ChannelMeta(Icons.help_outline_rounded, Color(0xFF5EAAD4)),
};

class _ChannelMeta {
  final IconData icon;
  final Color color;
  const _ChannelMeta(this.icon, this.color);
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scrollController = ScrollController();
  final _channelScrollController = ScrollController();

  /// FAB 是否已隐藏（向上滚动时隐藏以增大阅读区域）
  bool _fabVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedControllerProvider.notifier).loadInitial();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _channelScrollController.dispose();
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

    // FAB 显示/隐藏（向上滚 > 50 隐藏，向下滚 > 20 显示）
    final delta = currentScroll - _lastScrollOffset;
    if (delta > 50 && _fabVisible) {
      setState(() => _fabVisible = false);
    } else if (delta < -20 && !_fabVisible) {
      setState(() => _fabVisible = true);
    }
    _lastScrollOffset = currentScroll;
  }

  Future<void> _handleLike(PostItem post) async {
    try {
      final postRepo = ref.read(postRepositoryProvider);
      await postRepo.likePost(post.id);
      ref.invalidate(feedControllerProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请稍后重试')),
        );
      }
    }
  }

  Future<void> _handleFavorite(PostItem post) async {
    try {
      final postRepo = ref.read(postRepositoryProvider);
      if (post.isFavorited) {
        await postRepo.unfavoritePost(post.id);
      } else {
        await postRepo.favoritePost(post.id);
      }
      ref.invalidate(feedControllerProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请稍后重试')),
        );
      }
    }
  }

  /// 将指定 channel chip 滚动到可视区域中央
  void _scrollChannelToCenter(int index) {
    if (!_channelScrollController.hasClients) return;
    final scrollWidth = _channelScrollController.position.maxScrollExtent;
    if (scrollWidth <= 0) return;

    // 估算每个 chip 的宽度（padding 8 + 文字宽度 + 图标）
    const estimatedChipWidth = 90.0;
    final targetOffset = (index * estimatedChipWidth) -
        (MediaQuery.of(context).size.width / 2) +
        (estimatedChipWidth / 2);
    final clamped = targetOffset.clamp(0.0, scrollWidth);
    _channelScrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);

    return Scaffold(
      backgroundColor: MobileTheme.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(feedControllerProvider.notifier).refreshPosts();
        },
        color: MobileTheme.primary,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 大标题导航栏
            SliverAppBar(
              pinned: true,
              expandedHeight: 60,
              backgroundColor: MobileTheme.surface,
              elevation: 0,
              scrolledUnderElevation: 0.5,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: const FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  '西电树洞',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: MobileTheme.textPrimary,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push('/notifications'),
                ),
              ],
            ),

            // 频道横向滚动列表
            SliverPersistentHeader(
              pinned: true,
              delegate: _ChannelBarDelegate(
                channels: feedState.channels,
                selectedChannel: feedState.selectedChannel,
                scrollController: _channelScrollController,
                onChannelSelected: (channel, index) {
                  ref
                      .read(feedControllerProvider.notifier)
                      .switchChannel(channel);
                  _scrollChannelToCenter(index);
                },
              ),
            ),

            // 排序栏 + 发帖入口
            SliverToBoxAdapter(
              child: _SortAndPostBar(
                sort: feedState.sort,
                onSortChanged: (sort) {
                  ref.read(feedControllerProvider.notifier).switchSort(sort);
                },
                onPostTap: () => context.push('/post/create'),
              ),
            ),

            // 帖子列表
            if (feedState.loading && feedState.posts.isEmpty)
              const SliverFillRemaining(
                child: HomePageShimmer(),
              )
            else if (feedState.error != null && feedState.posts.isEmpty)
              SliverFillRemaining(
                child: _ErrorView(
                  message: feedState.error!,
                  onRetry: () {
                    ref.read(feedControllerProvider.notifier).loadInitial();
                  },
                ),
              )
            else if (feedState.posts.isEmpty)
              const SliverFillRemaining(
                child: _EmptyView(),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.only(top: 4, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == feedState.posts.length) {
                        if (feedState.hasMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MobileTheme.primary,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      final post = feedState.posts[index];
                      return PostCard(
                        key: ValueKey(post.id),
                        post: post,
                        onTap: () => context.push('/post/${post.id}'),
                        onLike: () => _handleLike(post),
                        onFavorite: () => _handleFavorite(post),
                      );
                    },
                    childCount:
                        feedState.posts.length + (feedState.hasMore ? 1 : 0),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),

      // 悬浮发帖按钮
      floatingActionButton: AnimatedSlide(
        offset: _fabVisible ? Offset.zero : const Offset(0, 2),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: _fabVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/post/create'),
            backgroundColor: MobileTheme.primary,
            elevation: 4,
            icon: const Icon(Icons.edit, color: Colors.white, size: 20),
            label: const Text(
              '发帖',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 频道栏 Delegate（SliverPersistentHeader 实现固定 + 背景效果）
// ---------------------------------------------------------------------------
class _ChannelBarDelegate extends SliverPersistentHeaderDelegate {
  final List<String> channels;
  final String selectedChannel;
  final ScrollController scrollController;
  final void Function(String channel, int index) onChannelSelected;

  _ChannelBarDelegate({
    required this.channels,
    required this.selectedChannel,
    required this.scrollController,
    required this.onChannelSelected,
  });

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  bool shouldRebuild(covariant _ChannelBarDelegate old) =>
      channels != old.channels || selectedChannel != old.selectedChannel;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final selectedIndex = channels.indexOf(selectedChannel);

    return Container(
      height: 56,
      color: MobileTheme.surface,
      child: Column(
        children: [
          // 频道横向列表
          Expanded(
            child: channels.isEmpty
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MobileTheme.primary,
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      // 频道列表
                      ListView.builder(
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: channels.length,
                        itemBuilder: (context, index) {
                          final channel = channels[index];
                          final isSelected = channel == selectedChannel;
                          final meta = _channelMeta[channel];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _ChannelChip(
                              label: channel,
                              icon: meta?.icon,
                              iconColor: meta?.color,
                              isSelected: isSelected,
                              isFirst: index == 0,
                              onTap: () => onChannelSelected(channel, index),
                            ),
                          );
                        },
                      ),

                      // 左侧渐变遮罩（滚动到左侧边界时提示可继续左滚）
                      if (selectedIndex > 1)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Container(
                              width: 24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    MobileTheme.surface,
                                    MobileTheme.surface.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 右侧渐变遮罩（滚动到右侧边界时提示可继续右滚）
                      if (selectedIndex < channels.length - 2)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Container(
                              width: 24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [
                                    MobileTheme.surface,
                                    MobileTheme.surface.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          // 底部极细分割线
          Container(
            height: 0.5,
            color: MobileTheme.divider,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 频道 Chip 组件
// ---------------------------------------------------------------------------
class _ChannelChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool isSelected;
  final bool isFirst;
  final VoidCallback onTap;

  const _ChannelChip({
    required this.label,
    this.icon,
    this.iconColor,
    required this.isSelected,
    this.isFirst = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        isSelected ? MobileTheme.primary : MobileTheme.textSecondary;
    final effectiveIconColor = iconColor ?? effectiveColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? MobileTheme.primary.withValues(alpha: 0.12)
              : MobileTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? MobileTheme.primary : MobileTheme.divider,
            width: isSelected ? 1.2 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: MobileTheme.primary.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: effectiveIconColor.withValues(
                    alpha: isSelected ? 1.0 : 0.75),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 排序栏 + 发帖入口
// ---------------------------------------------------------------------------
class _SortAndPostBar extends StatelessWidget {
  final PostSort sort;
  final void Function(PostSort) onSortChanged;
  final VoidCallback onPostTap;

  const _SortAndPostBar({
    required this.sort,
    required this.onSortChanged,
    required this.onPostTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 排序切换胶囊
          _SortToggle(sort: sort, onSortChanged: onSortChanged),

          // 发帖按钮
          GestureDetector(
            onTap: onPostTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [MobileTheme.primary, Color(0xFF1A7A95)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: MobileTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 14, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    '发帖',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
}

// ---------------------------------------------------------------------------
// 排序 Toggle 胶囊
// ---------------------------------------------------------------------------
class _SortToggle extends StatelessWidget {
  final PostSort sort;
  final void Function(PostSort) onSortChanged;

  const _SortToggle({
    required this.sort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MobileTheme.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MobileTheme.divider, width: 0.8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SortOption(
            label: '最新',
            isSelected: sort == PostSort.latest,
            onTap: () => onSortChanged(PostSort.latest),
          ),
          _SortOption(
            label: '热门',
            isSelected: sort == PostSort.likes,
            onTap: () => onSortChanged(PostSort.likes),
          ),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? MobileTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label == '热门')
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.local_fire_department,
                  size: 13,
                  color: isSelected
                      ? MobileTheme.accent
                      : MobileTheme.textTertiary,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color:
                    isSelected ? MobileTheme.primary : MobileTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 错误视图
// ---------------------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: MobileTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: MobileTheme.textSecondary,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: MobileTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 空状态视图
// ---------------------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: MobileTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 40,
                color: MobileTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '暂无帖子',
              style: TextStyle(
                color: MobileTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '成为第一个发布内容的人吧',
              style: TextStyle(
                color: MobileTheme.textTertiary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => context.push('/post/create'),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('发布帖子'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MobileTheme.primary,
                side: const BorderSide(color: MobileTheme.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
