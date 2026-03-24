import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../lib/models/post_item.dart';
import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';

/// 我的帖子列表页
class MyPostsPage extends ConsumerStatefulWidget {
  const MyPostsPage({super.key});

  @override
  ConsumerState<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends ConsumerState<MyPostsPage> {
  List<PostItem> _posts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      final posts = await postRepo.fetchMyPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MobileTheme.background,
      appBar: AppBar(
        backgroundColor: MobileTheme.surface,
        title: const Text('我的帖子'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _posts.isEmpty
                  ? _buildEmptyView()
                  : _buildList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: MobileTheme.textTertiary),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: MobileTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadPosts, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: MobileTheme.textTertiary),
          SizedBox(height: 16),
          Text('暂无帖子', style: TextStyle(fontSize: 16, color: MobileTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: MobileTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MobileTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MobileTheme.divider.withValues(alpha: 0.5)),
            ),
            child: InkWell(
              onTap: () => context.push('/post/${post.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: MobileTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(post.channel, style: const TextStyle(fontSize: 12, color: MobileTheme.primary, fontWeight: FontWeight.w600)),
                      ),
                      if (post.status == PostStatus.resolved) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MobileTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('已解决', style: TextStyle(fontSize: 10, color: MobileTheme.success, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(post.title.isNotEmpty ? post.title : post.content, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MobileTheme.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.favorite_border, size: 14, color: MobileTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text('${post.likeCount}', style: const TextStyle(fontSize: 12, color: MobileTheme.textTertiary)),
                      const SizedBox(width: 16),
                      const Icon(Icons.chat_bubble_outline, size: 14, color: MobileTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text('${post.commentCount}', style: const TextStyle(fontSize: 12, color: MobileTheme.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
