import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';
import '../../../lib/models/post_item.dart';
import '../../../lib/models/comment_item.dart';
import '../../../lib/repositories/post_repository.dart';
import 'image_gallery.dart';
import 'comment_input_bar.dart';

/// 帖子详情页
/// 包含帖子正文、图片画廊、评论列表、点赞/收藏/举报交互
class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailPage({
    super.key,
    required this.postId,
  });

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  PostItem? _post;
  List<CommentItem> _comments = [];
  bool _isLoading = true;
  String? _error;
  bool _isLiking = false;
  bool _isFavoriting = false;
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      final post = await postRepo.fetchPostDetail(widget.postId);
      final comments = await postRepo.fetchComments(widget.postId);

      if (mounted) {
        setState(() {
          _post = post;
          _comments = comments;
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

  Future<void> _handleLike() async {
    if (_isLiking || _post == null) return;

    // 乐观更新
    final previousPost = _post!;
    setState(() {
      _isLiking = true;
      _post = _post!.copyWith(
        likeCount: _post!.likeCount + 1,
      );
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      await postRepo.likePost(widget.postId);
    } catch (e) {
      // 回滚
      if (mounted) {
        setState(() {
          _post = previousPost;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点赞失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }

  Future<void> _handleFavorite() async {
    if (_isFavoriting || _post == null) return;

    // 乐观更新
    final previousPost = _post!;
    final wasFavorited = _post!.isFavorited;
    setState(() {
      _isFavoriting = true;
      _post = _post!.copyWith(
        isFavorited: !wasFavorited,
        favoriteCount: wasFavorited
            ? _post!.favoriteCount - 1
            : _post!.favoriteCount + 1,
      );
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      if (wasFavorited) {
        await postRepo.unfavoritePost(widget.postId);
      } else {
        await postRepo.favoritePost(widget.postId);
      }
    } catch (e) {
      // 回滚
      if (mounted) {
        setState(() {
          _post = previousPost;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFavoriting = false;
        });
      }
    }
  }

  Future<void> _handleReport() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MobileTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ReportSheet(postId: widget.postId, postRepo: ref.read(postRepositoryProvider)),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('举报成功，我们会尽快处理')),
      );
    }
  }

  Future<void> _handleSubmitComment(String content) async {
    if (_isPostingComment) return;

    setState(() {
      _isPostingComment = true;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      await postRepo.createComment(
        postId: widget.postId,
        content: content,
      );

      // 重新加载评论
      final comments = await postRepo.fetchComments(widget.postId);

      // 乐观更新帖子评论数
      if (mounted && _post != null) {
        setState(() {
          _post = _post!.copyWith(
            commentCount: _post!.commentCount + 1,
          );
          _comments = comments;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评论成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('评论失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPostingComment = false;
        });
      }
    }
  }

  void _handleDmRequest() async {
    if (_post == null) return;

    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      await messageRepo.createDmRequest(postId: widget.postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已发送私信申请，等待对方同意')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MobileTheme.background,
      appBar: AppBar(
        backgroundColor: MobileTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('帖子详情'),
        actions: [
          if (_post != null)
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showOptionsSheet(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _post == null
                  ? _buildEmptyView()
                  : _buildContent(),
      bottomNavigationBar: _post != null && _post!.allowComment
          ? CommentInputBar(
              onSubmit: _handleSubmitComment,
              autofocus: false,
            )
          : null,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: MobileTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: MobileTheme.textSecondary,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Text(
        '帖子不存在或已被删除',
        style: TextStyle(color: MobileTheme.textSecondary),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: MobileTheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 帖子内容
                  _buildPostContent(),

                  // 评论区
                  _buildCommentsSection(),
                ],
              ),
            ),
          ),
        ),

        // 底部操作栏
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildPostContent() {
    final post = _post!;

    return Container(
      color: MobileTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 头像
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MobileTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Text(
                      post.authorAlias.substring(0, 1),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: MobileTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorAlias,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: MobileTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatTime(post.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: MobileTheme.textTertiary,
                            ),
                          ),
                          if (post.status == PostStatus.resolved) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: MobileTheme.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '已解决',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: MobileTheme.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // 私信按钮
                if (post.allowDm && !post.isOwnPost)
                  TextButton.icon(
                    onPressed: _handleDmRequest,
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('私信'),
                    style: TextButton.styleFrom(
                      foregroundColor: MobileTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 标题
          if (post.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                post.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: MobileTheme.textPrimary,
                  height: 1.4,
                ),
              ),
            ),

          // 正文
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              post.content,
              style: const TextStyle(
                fontSize: 16,
                color: MobileTheme.textPrimary,
                height: 1.6,
              ),
            ),
          ),

          // 图片
          if (post.hasImage && post.imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PostImageGrid(imageUrls: post.imageUrls),
            ),

          // 标签
          if (post.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: post.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MobileTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 13,
                        color: MobileTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // 频道信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MobileTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    post.channel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MobileTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: MobileTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 评论区标题
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  '评论',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MobileTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_post!.commentCount} 条',
                  style: const TextStyle(
                    fontSize: 14,
                    color: MobileTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 评论列表
          if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  '暂无评论，快来抢沙发~',
                  style: TextStyle(
                    color: MobileTheme.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 60),
              itemBuilder: (context, index) {
                return _CommentTile(comment: _comments[index]);
              },
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final post = _post!;

    return Container(
      decoration: BoxDecoration(
        color: MobileTheme.surface,
        border: Border(
          top: BorderSide(color: MobileTheme.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 点赞
              _ActionItem(
                icon: Icons.favorite_border,
                activeIcon: Icons.favorite,
                label: post.likeCount > 0 ? '${post.likeCount}' : '点赞',
                isActive: false,
                isLoading: _isLiking,
                onTap: _handleLike,
              ),
              const SizedBox(width: 24),

              // 收藏
              _ActionItem(
                icon: Icons.star_border,
                activeIcon: Icons.star,
                label: post.favoriteCount > 0 ? '${post.favoriteCount}' : '收藏',
                isActive: post.isFavorited,
                isLoading: _isFavoriting,
                onTap: _handleFavorite,
              ),
              const SizedBox(width: 24),

              // 评论
              _ActionItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: post.commentCount > 0 ? '${post.commentCount}' : '评论',
                isActive: false,
                onTap: () {
                  // 滚动到评论区域
                },
              ),

              const Spacer(),

              // 分享
              IconButton(
                icon: const Icon(Icons.share_outlined),
                color: MobileTheme.textSecondary,
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: '查看西电树洞帖子: ${widget.postId}',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('链接已复制到剪贴板')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MobileTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: MobileTheme.error),
              title: const Text('举报'),
              onTap: () {
                Navigator.pop(context);
                _handleReport();
              },
            ),
            if (_post!.isOwnPost)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: MobileTheme.error),
                title: const Text('删除'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这篇帖子吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final postRepo = ref.read(postRepositoryProvider);
                await postRepo.deleteMyPost(widget.postId);
                if (mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('删除成功')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return DateFormat('MM-dd HH:mm').format(dateTime);
    }
  }
}

/// 评论列表项
class _CommentTile extends StatelessWidget {
  final CommentItem comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MobileTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                comment.authorAlias.substring(0, 1),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MobileTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorAlias,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MobileTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: MobileTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: MobileTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (comment.likeCount > 0) ...[
                      Icon(
                        Icons.favorite,
                        size: 14,
                        color: MobileTheme.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${comment.likeCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: MobileTheme.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return DateFormat('MM-dd').format(dateTime);
    }
  }
}

/// 底部操作按钮
class _ActionItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Row(
        children: [
          isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MobileTheme.textTertiary,
                  ),
                )
              : Icon(
                  isActive ? activeIcon : icon,
                  size: 22,
                  color: isActive ? MobileTheme.accent : MobileTheme.textSecondary,
                ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isActive ? MobileTheme.accent : MobileTheme.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// 举报表单
class _ReportSheet extends StatefulWidget {
  final String postId;
  final PostRepository postRepo;

  const _ReportSheet({required this.postId, required this.postRepo});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _selectedReason;
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  final _reasons = [
    '垃圾广告',
    '人身攻击',
    '色情低俗',
    '违法违规',
    '虚假信息',
    '侵犯隐私',
    '其他',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择举报原因')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final postRepo = widget.postRepo;
      await postRepo.report(
        targetType: 'post',
        targetId: widget.postId,
        reason: _selectedReason!,
        description: _descriptionController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, _selectedReason);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('举报失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '举报原因',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MobileTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((reason) {
              final isSelected = reason == _selectedReason;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MobileTheme.error.withValues(alpha: 0.1)
                        : MobileTheme.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? MobileTheme.error : MobileTheme.divider,
                    ),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? MobileTheme.error : MobileTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '补充说明（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: MobileTheme.error,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('提交举报'),
            ),
          ),
        ],
      ),
    );
  }
}
