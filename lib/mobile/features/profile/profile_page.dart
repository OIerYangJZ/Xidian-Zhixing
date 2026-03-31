import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../shell/mobile_shell.dart';
import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/models/user_profile.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/models/my_comment_item.dart';
import 'package:xdu_treehole_web/models/follow_user_item.dart';
import '../../core/state/mobile_providers.dart';
import '../widgets/avatar_widget.dart';
import '../home/post_card.dart';

/// 个人主页 — Twitter/Instagram 混合风格
/// 无卡片、无圆角、紧凑信息流布局
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  double _lastScrollOffset = 0;
  UserProfile? _profile;
  List<FollowUserItem> _followers = [];
  List<FollowUserItem> _following = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadProfile();
    _loadFollowData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final delta = _scrollController.position.pixels - _lastScrollOffset;
    if (delta > 1) {
      BottomNavVisibilityNotifier.instance.hide();
    } else if (delta < -1) {
      BottomNavVisibilityNotifier.instance.show();
    }
    _lastScrollOffset = _scrollController.position.pixels;
  }

  Future<void> _loadProfile() async {
    try {
      final repo = ref.read(userRepositoryProvider);
      final profile = await repo.fetchProfile();
      AuthStore.instance.setCurrentUser(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
    } catch (_) {
      // 使用缓存的 currentUser
      if (!mounted) return;
      setState(() {
        _profile = AuthStore.instance.currentUser;
      });
    }
  }

  Future<void> _loadFollowData() async {
    try {
      final repo = ref.read(userRepositoryProvider);
      final results = await Future.wait([
        repo.fetchFollowers(),
        repo.fetchFollowing(),
      ]);
      if (!mounted) return;
      setState(() {
        _followers = results[0];
        _following = results[1];
      });
    } catch (_) {}
  }

  void _showFollowSheet(String title, List<FollowUserItem> users) {
    final colors = MobileColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _FollowListSheet(title: title, users: users),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final user = _profile ?? AuthStore.instance.currentUser;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0.5,
        toolbarHeight: 48,
        title: Text(
          user?.nickname ?? '我的',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: colors.textPrimary, size: 22),
            onPressed: () => context.push('/profile/settings/main'),
          ),
        ],
      ),
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // 个人信息区
            SliverToBoxAdapter(
              child: Container(
                color: colors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 背景色条
                    Container(
                      height: 60,
                      color: MobileTheme.primary.withValues(alpha: 0.08),
                    ),

                    // 头像 + 编辑按钮
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // 头像（负 margin 向上重叠）
                          Transform.translate(
                            offset: const Offset(0, -24),
                            child: GestureDetector(
                              onTap: () => context.push('/profile/edit'),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: colors.surface, width: 4),
                                ),
                                child: AvatarWidget(
                                  avatarUrl: user?.avatarUrl,
                                  nickname: user?.nickname ?? '匿',
                                  radius: 36,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // 编辑资料按钮
                          Transform.translate(
                            offset: const Offset(0, -16),
                            child: GestureDetector(
                              onTap: () => context.push('/profile/edit'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  border: Border.all(
                                      color: colors.divider, width: 1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '编辑资料',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 昵称
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        user?.nickname ?? '匿名同学',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),

                    // 数据统计行（无卡片，紧凑横排）
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          _StatChip(
                            label: '粉丝',
                            value: '${_followers.length}',
                            onTap: () => _showFollowSheet('粉丝', _followers),
                          ),
                          const SizedBox(width: 20),
                          _StatChip(
                            label: '关注',
                            value: '${_following.length}',
                            onTap: () => _showFollowSheet('关注', _following),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: MobileTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user?.userLevelLabel ?? 'Lv.1',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: MobileTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 0.5, color: colors.divider),

                    // TabBar
                    TabBar(
                      controller: _tabController,
                      labelColor: colors.textPrimary,
                      unselectedLabelColor: colors.textSecondary,
                      indicatorColor: MobileTheme.primary,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      isScrollable: false,
                      tabs: const [
                        Tab(text: '帖子'),
                        Tab(text: '收藏'),
                        Tab(text: '动态'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _MyPostsTab(),
            _MyFavoritesTab(),
            _MyActivitiesTab(),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatChip({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final row = Row(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: row);
    }
    return row;
  }
}

/// 关注/粉丝列表底部弹出面板
class _FollowListSheet extends StatelessWidget {
  final String title;
  final List<FollowUserItem> users;

  const _FollowListSheet({required this.title, required this.users});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final mutual = users.where((u) => u.isMutual).toList();
    final others = users.where((u) => !u.isMutual).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${users.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 0.5, color: colors.divider),
            // 列表
            Expanded(
              child: users.isEmpty
                  ? Center(
                      child: Text(
                        '暂无数据',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textTertiary,
                        ),
                      ),
                    )
                  : ListView(
                      controller: scrollCtrl,
                      children: [
                        if (mutual.isNotEmpty) ...[
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              '好友',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          ...mutual.map((u) => _FollowUserTile(user: u)),
                          if (others.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                '其他',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                        ...others.map((u) => _FollowUserTile(user: u)),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FollowUserTile extends StatelessWidget {
  final FollowUserItem user;

  const _FollowUserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return ListTile(
      leading: AvatarWidget(
        avatarUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
        nickname: user.nickname,
        radius: 20,
      ),
      title: Text(
        user.nickname,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
      ),
      trailing: user.isMutual
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MobileTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '好友',
                style: TextStyle(
                  fontSize: 12,
                  color: MobileTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }
}

/// 我的帖子 Tab — 真实数据
class _MyPostsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MyPostsTab> createState() => _MyPostsTabState();
}

class _MyPostsTabState extends ConsumerState<_MyPostsTab> {
  List<PostItem> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await ref.read(postRepositoryProvider).fetchMyPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: MobileTheme.primary));
    }
    if (_posts.isEmpty) {
      return const _EmptyHint(icon: Icons.article_outlined, text: '还没有发过帖子');
    }
    return ListView.builder(
      itemCount: _posts.length,
      itemBuilder: (context, i) {
        final post = _posts[i];
        return PostCard(
          post: post,
          onTap: () => context.push('/post/${post.id}'),
          onLike: () async {
            try {
              final repo = ref.read(postRepositoryProvider);
              if (post.isLiked) {
                await repo.unlikePost(post.id);
              } else {
                await repo.likePost(post.id);
              }
              _load();
            } catch (_) {}
          },
          onFavorite: () async {
            try {
              final repo = ref.read(postRepositoryProvider);
              if (post.isFavorited) {
                await repo.unfavoritePost(post.id);
              } else {
                await repo.favoritePost(post.id);
              }
              _load();
            } catch (_) {}
          },
        );
      },
    );
  }
}

/// 我的收藏 Tab — 真实数据
class _MyFavoritesTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MyFavoritesTab> createState() => _MyFavoritesTabState();
}

class _MyFavoritesTabState extends ConsumerState<_MyFavoritesTab> {
  List<PostItem> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await ref.read(postRepositoryProvider).fetchFavoritePosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: MobileTheme.primary));
    }
    if (_posts.isEmpty) {
      return const _EmptyHint(icon: Icons.star_outline, text: '还没有收藏');
    }
    return ListView.builder(
      itemCount: _posts.length,
      itemBuilder: (context, i) {
        final post = _posts[i];
        return PostCard(
          post: post,
          onTap: () => context.push('/post/${post.id}'),
          onLike: () async {
            try {
              final repo = ref.read(postRepositoryProvider);
              if (post.isLiked) {
                await repo.unlikePost(post.id);
              } else {
                await repo.likePost(post.id);
              }
              _load();
            } catch (_) {}
          },
          onFavorite: () async {
            try {
              final repo = ref.read(postRepositoryProvider);
              if (post.isFavorited) {
                await repo.unfavoritePost(post.id);
              } else {
                await repo.favoritePost(post.id);
              }
              _load();
            } catch (_) {}
          },
        );
      },
    );
  }
}

/// 动态 Tab — 我的评论真实数据
class _MyActivitiesTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MyActivitiesTab> createState() => _MyActivitiesTabState();
}

class _MyActivitiesTabState extends ConsumerState<_MyActivitiesTab> {
  List<MyCommentItem> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final comments =
          await ref.read(userRepositoryProvider).fetchMyComments();
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: MobileTheme.primary));
    }
    if (_comments.isEmpty) {
      return _EmptyHint(icon: Icons.comment_outlined, text: '还没有评论过');
    }
    return ListView.separated(
      itemCount: _comments.length,
      separatorBuilder: (_, __) =>
          Divider(height: 0.5, color: colors.divider),
      itemBuilder: (context, i) {
        final c = _comments[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.postTitle,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                c.content,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textPrimary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                c.timeText,
                style: TextStyle(
                    fontSize: 12, color: colors.textTertiary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(icon, size: 48, color: colors.divider),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
