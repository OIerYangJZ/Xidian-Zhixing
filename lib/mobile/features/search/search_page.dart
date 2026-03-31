import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/models/public_user_profile.dart';
import '../home/post_card.dart';
import '../widgets/avatar_widget.dart';

/// 搜索页
/// 支持搜索帖子和用户
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

enum SearchTab { posts, users }

class _SearchPageState extends ConsumerState<SearchPage> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  late TabController _tabController;

  SearchTab _currentTab = SearchTab.posts;
  bool _isSearching = false;
  List<PostItem> _postResults = [];
  PublicUserProfile? _userResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTab = _tabController.index == 0 ? SearchTab.posts : SearchTab.users;
          _postResults = [];
          _userResult = null;
          _searchController.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      if (_currentTab == SearchTab.posts) {
        final results = await ref.read(postRepositoryProvider).fetchPosts(keyword: keyword);
        if (mounted) setState(() => _postResults = results);
      } else {
        final user = await ref.read(userRepositoryProvider).fetchUserProfile(keyword);
        if (mounted) setState(() => _userResult = user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_currentTab == SearchTab.posts ? '搜索失败' : '用户不存在')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            TabBar(
              controller: _tabController,
              labelColor: MobileTheme.primary,
              unselectedLabelColor: colors.textSecondary,
              indicatorColor: MobileTheme.primary,
              tabs: const [
                Tab(text: '搜索帖子'),
                Tab(text: '搜索用户'),
              ],
            ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _currentTab == SearchTab.posts
                      ? _buildPostResults()
                      : _buildUserResult(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final colors = MobileColors.of(context);
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _handleSearch(),
              decoration: InputDecoration(
                hintText: _currentTab == SearchTab.posts ? '搜索帖子...' : '输入用户ID...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _postResults = [];
                            _userResult = null;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostResults() {
    if (_postResults.isEmpty) {
      return Center(
        child: Text(
          '输入关键词搜索帖子',
          style: TextStyle(color: MobileColors.of(context).textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: _postResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final post = _postResults[index];
        return PostCard(
          post: post,
          onTap: () => context.push('/post/${post.id}'),
        );
      },
    );
  }

  Widget _buildUserResult() {
    if (_userResult == null) {
      return Center(
        child: Text(
          '输入用户ID搜索',
          style: TextStyle(color: MobileColors.of(context).textSecondary),
        ),
      );
    }
    final colors = MobileColors.of(context);
    final user = _userResult!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onTap: () => context.push('/user/${user.userId}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AvatarWidget(
                  avatarUrl: user.avatarUrl,
                  nickname: user.nickname,
                  radius: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nickname,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (user.bio.isNotEmpty)
                        Text(
                          user.bio,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
