import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../widgets/avatar_widget.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/models/comment_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
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
  bool _isFollowing = false;

  // 回复状态
  CommentItem? _replyingTo;

  // 用于键盘弹起时自动滚动到底部
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
          _comments = _buildCommentTree(comments);
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

  /// 将扁平的评论列表转换为嵌套树结构
  List<CommentItem> _buildCommentTree(List<CommentItem> flat) {
    final Map<String, CommentItem> map = {};
    for (final c in flat) {
      map[c.id] = CommentItem(
        id: c.id,
        authorAlias: c.authorAlias,
        content: c.content,
        createdAt: c.createdAt,
        likeCount: c.likeCount,
        authorAvatar: c.authorAvatar,
        isLiked: c.isLiked,
        isPinned: c.isPinned,
        parentId: c.parentId,
        replies: [],
      );
    }
    final List<CommentItem> roots = [];
    for (final c in flat) {
      final node = map[c.id]!;
      if (c.parentId.isEmpty || !map.containsKey(c.parentId)) {
        roots.add(node);
      } else {
        map[c.parentId]!.replies.add(node);
      }
    }
    return roots;
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
        favoriteCount:
            wasFavorited ? _post!.favoriteCount - 1 : _post!.favoriteCount + 1,
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
      builder: (context) => _ReportSheet(
          postId: widget.postId, postRepo: ref.read(postRepositoryProvider)),
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
        parentId: _replyingTo?.id,
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
          _replyingTo = null; // 清空回复状态
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
    if (_post == null || !_post!.canMessageAuthor) return;

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

  Future<void> _handleFollowAuthor() async {
    final post = _post;
    if (post == null ||
        _isFollowing ||
        !post.canFollowAuthor ||
        post.authorUserId.isEmpty) {
      return;
    }

    setState(() {
      _isFollowing = true;
    });
    try {
      final userRepo = ref.read(userRepositoryProvider);
      if (post.isFollowingAuthor) {
        await userRepo.unfollowUser(post.authorUserId);
      } else {
        await userRepo.followUser(post.authorUserId);
      }
      if (!mounted) {
        return;
      }
      final bool nextFollowing = !post.isFollowingAuthor;
      setState(() {
        _post = post.copyWith(isFollowingAuthor: nextFollowing);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(nextFollowing ? '关注成功' : '已取消关注')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowing = false;
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
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingTo != null) _buildReplyBanner(),
                CommentInputBar(
                  onSubmit: _handleSubmitComment,
                  autofocus: false,
                  scrollController: _scrollController,
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildReplyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: MobileTheme.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: MobileTheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '回复 @${_replyingTo!.authorAlias}',
              style: const TextStyle(
                fontSize: 13,
                color: MobileTheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyingTo = null),
            child: const Icon(
              Icons.close,
              size: 16,
              color: MobileTheme.primary,
            ),
          ),
        ],
      ),
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
                controller: _scrollController,
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                // 头像
                GestureDetector(
                  onTap: () {
                    if (post.isOwnPost) {
                      context.push('/profile');
                    } else if (!post.isAnonymous && post.authorUserId.isNotEmpty) {
                      context.push('/user/${post.authorUserId}');
                    }
                  },
                  child: AvatarWidget(
                    avatarUrl: post.isAnonymous ? null : post.authorAvatarUrl,
                    nickname: post.authorAlias,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorAlias,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: MobileTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
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
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    MobileTheme.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(3),
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
                if (post.canFollowAuthor && post.authorUserId.isNotEmpty)
                  TextButton.icon(
                    onPressed: _isFollowing ? null : _handleFollowAuthor,
                    icon: Icon(
                      post.isFollowingAuthor
                          ? Icons.person_remove_alt_1_outlined
                          : Icons.person_add_alt_1_outlined,
                      size: 16,
                    ),
                    label: Text(post.isFollowingAuthor ? '取消关注' : '关注'),
                    style: TextButton.styleFrom(
                      foregroundColor: MobileTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                // 私信按钮
                if (post.canMessageAuthor)
                  TextButton.icon(
                    onPressed: _handleDmRequest,
                    icon: const Icon(Icons.mail_outline, size: 16),
                    label: const Text('私信'),
                    style: TextButton.styleFrom(
                      foregroundColor: MobileTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 标题
          if (post.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                post.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: MobileTheme.textPrimary,
                  height: 1.35,
                ),
              ),
            ),

          // 正文
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              post.content,
              style: const TextStyle(
                fontSize: 16,
                color: MobileTheme.textPrimary,
                height: 1.55,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: post.tags.map((tag) {
                  return Text(
                    '#$tag',
                    style: const TextStyle(
                      fontSize: 13,
                      color: MobileTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
            ),

          // 频道信息
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: MobileTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(3),
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
      color: MobileTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 评论区标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text(
                  '评论',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MobileTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_post!.commentCount} 条',
                  style: const TextStyle(
                    fontSize: 13,
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
              padding: EdgeInsets.symmetric(vertical: 32),
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
            _buildCommentList(_comments),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final post = _post!;

    return Container(
      decoration: const BoxDecoration(
        color: MobileTheme.surface,
        border: Border(
          top: BorderSide(color: MobileTheme.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              const SizedBox(width: 20),

              // 收藏
              _ActionItem(
                icon: Icons.star_border,
                activeIcon: Icons.star,
                label: post.favoriteCount > 0 ? '${post.favoriteCount}' : '收藏',
                isActive: post.isFavorited,
                isLoading: _isFavoriting,
                onTap: _handleFavorite,
              ),
              const SizedBox(width: 20),

              // 评论
              _ActionItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: post.commentCount > 0 ? '${post.commentCount}' : '评论',
                isActive: false,
                onTap: () {},
              ),

              const Spacer(),

              // 分享
              IconButton(
                icon: const Icon(Icons.share_outlined),
                color: MobileTheme.textSecondary,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
              leading:
                  const Icon(Icons.flag_outlined, color: MobileTheme.error),
              title: const Text('举报'),
              onTap: () {
                Navigator.pop(context);
                _handleReport();
              },
            ),
            if (_post!.isOwnPost)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: MobileTheme.error),
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

  /// 递归渲染嵌套评论列表
  Widget _buildCommentList(List<CommentItem> comments, {bool isNested = false}) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      separatorBuilder: (_, __) => isNested
          ? const SizedBox.shrink()
          : const Divider(height: 1, indent: 60),
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _CommentTile(
          comment: comment,
          indentLevel: isNested ? 1 : 0,
          onReply: () => setState(() => _replyingTo = comment),
        );
      },
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
  final VoidCallback? onReply;
  final int indentLevel;

  const _CommentTile({
    required this.comment,
    this.onReply,
    this.indentLevel = 0,
  });

  @override
  Widget build(BuildContext context) {
    // 头像尺寸：每缩进一层缩小2dp，最多缩到10dp
    final double avatarRadius = (17 - indentLevel * 2).clamp(10, 17).toDouble();
    // 左侧缩进：每层20dp，最大缩进60dp
    final double leftPadding = (indentLevel * 20).clamp(0, 60).toDouble();
    // 最多渲染3层嵌套（indentLevel 0/1/2），超过则不再缩进但继续渲染
    final int effectiveIndent = indentLevel.clamp(0, 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧缩进 + 竖线
              SizedBox(
                width: leftPadding + (effectiveIndent > 0 ? 12 : 16),
                child: effectiveIndent > 0
                    ? Row(
                        children: [
                          SizedBox(width: leftPadding),
                          ...List.generate(effectiveIndent, (i) {
                            return Container(
                              width: 2,
                              margin: const EdgeInsets.only(right: 10),
                              color: MobileTheme.divider,
                            );
                          }),
                        ],
                      )
                    : SizedBox(width: leftPadding),
              ),
              // 头像
              GestureDetector(
                onTap: comment.authorUserId.isNotEmpty
                    ? () => context.push('/user/${comment.authorUserId}')
                    : null,
                child: AvatarWidget(
                  avatarUrl: comment.authorAvatar,
                  nickname: comment.authorAlias,
                  radius: avatarRadius,
                ),
              ),
              const SizedBox(width: 10),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.authorAlias,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MobileTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(comment.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: MobileTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      comment.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: MobileTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (comment.likeCount > 0) ...[
                          const Icon(
                            Icons.favorite,
                            size: 13,
                            color: MobileTheme.accent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${comment.likeCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MobileTheme.textTertiary,
                            ),
                          ),
                        ],
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: onReply,
                          child: const Row(
                            children: [
                              Icon(
                                Icons.reply,
                                size: 13,
                                color: MobileTheme.textTertiary,
                              ),
                              SizedBox(width: 3),
                              Text(
                                '回复',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MobileTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 递归渲染子回复（最多嵌套3层）
        if (comment.replies.isNotEmpty && indentLevel < 3)
          ...comment.replies.map(
            (reply) => _CommentTile(
              comment: reply,
              indentLevel: indentLevel + 1,
              onReply: () {},
            ),
          ),
      ],
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
                  color:
                      isActive ? MobileTheme.accent : MobileTheme.textSecondary,
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
                      color:
                          isSelected ? MobileTheme.error : MobileTheme.divider,
                    ),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? MobileTheme.error
                          : MobileTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
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
