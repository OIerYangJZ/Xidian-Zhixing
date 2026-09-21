import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../../features/search/search_controller.dart' as shared_search;
import '../home/post_card.dart';
import '../widgets/avatar_widget.dart';

/// 搜索页
/// 支持搜索帖子和用户
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(shared_search.searchControllerProvider.notifier).updateTab(
          _tabController.index == 0
              ? shared_search.SearchResultTab.posts
              : shared_search.SearchResultTab.users,
        );
        _searchController.clear();
        ref.read(shared_search.searchControllerProvider.notifier).clearQuery();
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
    final String keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      return;
    }

    final shared_search.SearchController controller =
        ref.read(shared_search.searchControllerProvider.notifier);
    controller.setKeyword(keyword);
    await controller.search();
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final shared_search.SearchState state =
        ref.watch(shared_search.searchControllerProvider);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            TabBar(
              controller: _tabController,
              labelColor: MobileTheme.primaryOf(context),
              unselectedLabelColor: colors.textSecondary,
              indicatorColor: MobileTheme.primaryOf(context),
              tabs: const [
                Tab(text: '搜索帖子'),
                Tab(text: '搜索用户'),
              ],
            ),
            Expanded(
              child: state.searching
                  ? const Center(child: CircularProgressIndicator())
                  : state.selectedTab == shared_search.SearchResultTab.posts
                  ? _buildPostResults(state)
                  : _buildUserResult(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final colors = MobileColors.of(context);
    final shared_search.SearchState state =
        ref.watch(shared_search.searchControllerProvider);
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
               onChanged: (value) => ref
                   .read(shared_search.searchControllerProvider.notifier)
                   .setKeyword(value),
              onSubmitted: (_) => _handleSearch(),
              decoration: InputDecoration(
                hintText: state.selectedTab == shared_search.SearchResultTab.posts
                    ? '搜索帖子...'
                    : '输入昵称关键词...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: state.keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(shared_search.searchControllerProvider.notifier)
                              .clearQuery();
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: ref.watch(shared_search.searchControllerProvider).searching
                  ? null
                  : _handleSearch,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('搜索'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostResults(shared_search.SearchState state) {
    if (state.error != null) {
      return _buildSearchError(state);
    }
    if (state.keyword.trim().isEmpty) {
      return Center(
        child: Text(
          '输入关键词搜索帖子',
          style: TextStyle(color: MobileColors.of(context).textSecondary),
        ),
      );
    }
    if (state.results.isEmpty) {
      return Center(
        child: Text(
          '没有找到匹配帖子',
          style: TextStyle(color: MobileColors.of(context).textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: state.results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final post = state.results[index];
        return PostCard(
          post: post,
          onTap: () => context.push('/post/${post.id}'),
        );
      },
    );
  }

  Widget _buildUserResult(shared_search.SearchState state) {
    if (state.error != null) {
      return _buildSearchError(state);
    }
    if (state.keyword.trim().isEmpty) {
      return Center(
        child: Text(
          '输入昵称后可模糊搜索用户',
          style: TextStyle(color: MobileColors.of(context).textSecondary),
        ),
      );
    }
    if (state.userResults.isEmpty) {
      return Center(
        child: Text(
          '没有找到匹配用户',
          style: TextStyle(color: MobileColors.of(context).textSecondary),
        ),
      );
    }
    final colors = MobileColors.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.userResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = state.userResults[index];
        return GestureDetector(
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
        );
      },
    );
  }

  Widget _buildSearchError(shared_search.SearchState state) {
    final colors = MobileColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 42, color: colors.textTertiary),
          const SizedBox(height: 10),
          Text(state.error!, style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 10),
          TextButton(onPressed: _handleSearch, child: const Text('重试')),
        ],
      ),
    );
  }
}
