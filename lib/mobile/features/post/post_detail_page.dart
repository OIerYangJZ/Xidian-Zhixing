import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xdu_treehole_web/core/auth/auth_store.dart';

import '../widgets/avatar_widget.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/utils/time_utils.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/models/comment_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'package:xdu_treehole_web/widgets/post_content_body.dart';
import 'image_gallery.dart';
import 'comment_input_bar.dart';

/// 甯栧瓙璇︽儏椤?
/// 鍖呭惈甯栧瓙姝ｆ枃銆佸浘鐗囩敾寤娿€佽瘎璁哄垪琛ㄣ€佺偣璧?鏀惰棌/涓炬姤浜や簰
class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;
  final String? initialCommentId;

  const PostDetailPage({
    super.key,
    required this.postId,
    this.initialCommentId,
  });

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  PostItem? _post;
  bool _postIsLiked = false;
  List<CommentItem> _comments = [];
  bool _isLoading = true;
  String? _error;
  bool _isLiking = false;
  bool _isFavoriting = false;
  bool _isPostingComment = false;
  bool _isFollowing = false;
  bool _isDeletingComment = false;
  bool _showEmoji = false;

  // 鍥炲鐘舵€?
  CommentItem? _replyingTo;

  // 鐢ㄤ簬閿洏寮硅捣鏃惰嚜鍔ㄦ粴鍔ㄥ埌搴曢儴
  final ScrollController _scrollController = ScrollController();

  // 鐢ㄤ簬婊氬姩鍒拌瘎璁哄尯
  final GlobalKey _commentsSectionKey = GlobalKey();

  // 鐢ㄤ簬鎿嶄綔璇勮杈撳叆妗?
  final GlobalKey<dynamic> _commentInputKey = GlobalKey();
  final Map<String, GlobalKey> _commentItemKeys = <String, GlobalKey>{};
  String _initialCommentId = '';
  bool _didHandleInitialCommentScroll = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initialCommentId = (widget.initialCommentId ?? '').trim();
    _ensureCurrentUserLoaded();
    _loadData(recordView: true);
  }

  String get _currentUserId => AuthStore.instance.currentUser?.userId ?? '';

  Future<void> _ensureCurrentUserLoaded() async {
    if (_currentUserId.isNotEmpty) {
      return;
    }
    try {
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      AuthStore.instance.setCurrentUser(profile);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadData({bool recordView = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      if (recordView) {
        await postRepo.incrementView(widget.postId);
      }
      final post = await postRepo.fetchPostDetail(widget.postId);
      final comments = await postRepo.fetchComments(widget.postId);

      if (mounted) {
        setState(() {
          _post = post;
          _postIsLiked = post.isLiked;
          _commentItemKeys.clear();
          _comments = _buildCommentTree(comments);
          _isLoading = false;
        });
        _scrollToInitialCommentIfNeeded();
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

  /// 灏嗘墎骞崇殑璇勮鍒楄〃杞崲涓哄祵濂楁爲缁撴瀯
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
        authorUserId: c.authorUserId,
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

    final wasLiked = _postIsLiked;
    final previousPost = _post!;
    setState(() {
      _isLiking = true;
      _post = _post!.copyWith(
        likeCount: wasLiked ? _post!.likeCount - 1 : _post!.likeCount + 1,
      );
      _postIsLiked = !wasLiked;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      if (wasLiked) {
        await postRepo.unlikePost(widget.postId);
      } else {
        await postRepo.likePost(widget.postId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _post = previousPost;
          _postIsLiked = wasLiked;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('鎿嶄綔澶辫触: $e')));
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

    // 涔愯鏇存柊
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
      // 鍥炴粴
      if (mounted) {
        setState(() {
          _post = previousPost;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('鎿嶄綔澶辫触: $e')));
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
    final colors = MobileColors.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ReportSheet(
        postId: widget.postId,
        postRepo: ref.read(postRepositoryProvider),
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('涓炬姤鎴愬姛锛屾垜浠細灏藉揩澶勭悊')));
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

      // 閲嶆柊鍔犺浇璇勮
      final comments = await postRepo.fetchComments(widget.postId);

      // 涔愯鏇存柊甯栧瓙璇勮鏁?
      if (mounted && _post != null) {
        setState(() {
          _post = _post!.copyWith(commentCount: _post!.commentCount + 1);
          _comments = _buildCommentTree(comments);
          _replyingTo = null; // 娓呯┖鍥炲鐘舵€?
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('璇勮鎴愬姛')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('璇勮澶辫触: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPostingComment = false;
        });
      }
    }
  }

  void _handleDm() async {
    if (_post == null || !_post!.canMessageAuthor) return;
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final conversation = await messageRepo.createDirectConversation(
        _post!.authorUserId,
        fromPostId: _post!.id,
      );
      if (!mounted) return;
      context.push(
        '/chat/${conversation.id}?name=${Uri.encodeComponent(conversation.name)}&avatar=${Uri.encodeComponent(conversation.avatarUrl)}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('鏃犳硶鍙戣捣绉佷俊: $e')));
    }
  }

  Future<void> _handleFollowAuthor() async {
    final post = _post;
    if (post == null ||
        _isFollowing ||
        post.isFollowingAuthor ||
        !post.canFollowAuthor ||
        post.authorUserId.isEmpty) {
      return;
    }

    setState(() {
      _isFollowing = true;
    });
    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.followUser(post.authorUserId);
      if (!mounted) {
        return;
      }
      setState(() {
        _post = post.copyWith(isFollowingAuthor: true);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('鍏虫敞鎴愬姛')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('鎿嶄綔澶辫触: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowing = false;
        });
      }
    }
  }

  Future<void> _handleDeleteComment(CommentItem comment) async {
    if (_isDeletingComment) {
      return;
    }
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete Comment'),
            content: const Text('Delete this comment permanently?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('鍙栨秷'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  '鍒犻櫎',
                  style: TextStyle(color: MobileTheme.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    setState(() {
      _isDeletingComment = true;
    });
    try {
      await ref.read(userRepositoryProvider).deleteMyComment(comment.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comment deleted')));
      await _loadData(recordView: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('鍒犻櫎澶辫触: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingComment = false;
        });
      }
    }
  }

  void _scrollToComments() {
    final keyContext = _commentsSectionKey.currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
  }

  GlobalKey _commentKeyFor(String commentId) {
    return _commentItemKeys.putIfAbsent(commentId, () => GlobalKey());
  }

  void _scrollToInitialCommentIfNeeded() {
    if (_didHandleInitialCommentScroll || _initialCommentId.isEmpty) {
      return;
    }
    _didHandleInitialCommentScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final GlobalKey? key = _commentItemKeys[_initialCommentId];
      final BuildContext? targetContext = key?.currentContext;
      if (targetContext == null) {
        _scrollToComments();
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    });
  }

  void _toggleEmoji() {
    // 鏀惰捣閿洏锛岄槻姝㈤敭鐩樺拰琛ㄦ儏鏍忓悓鏃跺嚭鐜板鑷村竷灞€绌虹櫧
    FocusScope.of(context).unfocus();
    setState(() {
      _showEmoji = !_showEmoji;
    });
  }

  void _onEmojiTap(String emoji) {
    // 閫氳繃 GlobalKey 鎵惧埌 CommentInputBar 鍐呴儴鐘舵€侊紝璋冪敤 insertEmoji
    final inputState = _commentInputKey.currentState;
    if (inputState != null) {
      // dynamic call 鈥?insertEmoji 鏄?_CommentInputBarState 鐨勫叕寮€鏂规硶
      // ignore: avoid_dynamic_calls
      inputState.insertEmoji(emoji);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('甯栧瓙璇︽儏'),
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
          ? Container(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.divider, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingTo != null) _buildReplyBanner(),
                    _buildBottomBarWithEmoji(),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBottomBarWithEmoji() {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CommentInputBar(
              key: _commentInputKey,
              onSubmit: _handleSubmitComment,
              autofocus: false,
              scrollController: _scrollController,
              onEmojiToggle: _toggleEmoji,
            ),
            SizedBox(height: _showEmoji ? 200 : 0),
          ],
        ),
        if (_showEmoji)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: EmojiPickerBar(onEmojiTap: _onEmojiTap),
          ),
      ],
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
              '鍥炲 @${_replyingTo!.authorAlias}',
              style: const TextStyle(fontSize: 13, color: MobileTheme.primary),
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
    final colors = MobileColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colors.textTertiary),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: colors.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadData, child: const Text('閲嶈瘯')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final colors = MobileColors.of(context);
    return Center(
      child: Text('甯栧瓙涓嶅瓨鍦ㄦ垨宸茶鍒犻櫎', style: TextStyle(color: colors.textSecondary)),
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
                  // 甯栧瓙鍐呭
                  _buildPostContent(),

                  // 鎿嶄綔鏍忥細鐐硅禐/鏀惰棌/璇勮/鍒嗕韩
                  _buildActionBar(),

                  const Divider(height: 1),

                  // 璇勮鍖?
                  _buildCommentsSection(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostContent() {
    final colors = MobileColors.of(context);
    final post = _post!;
    final List<String> supplementaryImageUrls = _supplementaryImageUrls(post);

    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 浣滆€呬俊鎭?
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                // 澶村儚
                GestureDetector(
                  onTap: () {
                    // 鍖垮悕甯栨垨鑷繁鐨勫笘瀛愪笉璺宠浆锛堣嚜宸辩殑甯栧瓙鏃犳硶浠庡叏灞忛〉 push Shell 鍒嗘敮璺敱锛?
                    if (!post.isAnonymous &&
                        post.authorUserId.isNotEmpty &&
                        !post.isOwnPost) {
                      context.push('/user/${post.authorUserId}');
                    }
                  },
                  child: AvatarWidget(
                    avatarUrl: post.isAnonymous ? null : post.authorAvatarUrl,
                    nickname: post.authorAlias,
                    radius: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorAlias,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text(
                            _formatTime(post.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textTertiary,
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
                                color: MobileTheme.success.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'Resolved',
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
                if (post.canFollowAuthor &&
                    post.authorUserId.isNotEmpty &&
                    !post.isFollowingAuthor)
                  TextButton.icon(
                    onPressed: _isFollowing ? null : _handleFollowAuthor,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                    label: const Text('鍏虫敞'),
                    style: TextButton.styleFrom(
                      foregroundColor: MobileTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
              ],
            ),
          ),

          // 鏍囬
          if (post.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 4),
              child: Text(
                post.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),

          // 姝ｆ枃
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 12, color: colors.textPrimary),
              child: PostContentBody(
                content: post.content,
                contentFormat: post.contentFormat,
                markdownSource: post.markdownSource,
                selectable: true,
              ),
            ),
          ),

          // 鍥剧墖
          if (post.hasImage && supplementaryImageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PostImageGrid(imageUrls: supplementaryImageUrls),
            ),

          // 鏍囩
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
        ],
      ),
    );
  }

  List<String> _supplementaryImageUrls(PostItem post) {
    if (!post.isMarkdown || post.markdownSource.trim().isEmpty) {
      return post.imageUrls;
    }
    return post.imageUrls
        .where((String url) => !post.markdownSource.contains(url))
        .toList();
  }

  Widget _buildCommentsSection() {
    final colors = MobileColors.of(context);
    return Container(
      key: _commentsSectionKey,
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 璇勮鍖烘爣棰?
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  '璇勮',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),

          // 璇勮鍒楄〃
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '鏆傛棤璇勮锛屽揩鏉ユ姠娌欏彂~',
                  style: TextStyle(color: colors.textTertiary, fontSize: 14),
                ),
              ),
            )
          else
            _buildCommentList(_comments),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final post = _post!;
    final colors = MobileColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        children: [
          // 鐐硅禐
          _ActionItem(
            icon: Icons.favorite_border,
            activeIcon: Icons.favorite,
            label: post.likeCount > 0 ? '${post.likeCount}' : '',
            isActive: _postIsLiked,
            isLoading: _isLiking,
            activeColor: const Color(0xFFFF2D55),
            onTap: _handleLike,
          ),
          const SizedBox(width: 22),

          // 鏀惰棌
          _ActionItem(
            icon: Icons.star_border,
            activeIcon: Icons.star,
            label: post.favoriteCount > 0 ? '${post.favoriteCount}' : '',
            isActive: post.isFavorited,
            isLoading: _isFavoriting,
            activeColor: const Color(0xFFFF9500),
            onTap: _handleFavorite,
            iconSize: 25,
          ),
          const SizedBox(width: 22),

          // 璇勮
          _ActionItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            label: post.commentCount > 0 ? '${post.commentCount}' : '',
            isActive: false,
            activeColor: MobileTheme.primary,
            onTap: () {
              _scrollToComments();
            },
          ),

          const Spacer(),

          // 鍒嗕韩
          IconButton(
            icon: Icon(Icons.share_outlined, color: colors.textPrimary),
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: '鏌ョ湅瑗跨數鏍戞礊甯栧瓙: ${widget.postId}'),
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet() {
    final colors = MobileColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: MobileTheme.error,
              ),
              title: const Text('涓炬姤'),
              onTap: () {
                Navigator.pop(context);
                _handleReport();
              },
            ),
            if (_post!.isOwnPost)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: MobileTheme.error,
                ),
                title: const Text('鍒犻櫎'),
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
        title: const Text('纭鍒犻櫎'),
        content: const Text('Delete this post permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('鍙栨秷'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final postRepo = ref.read(postRepositoryProvider);
                await postRepo.deleteMyPost(widget.postId);
                if (mounted) {
                  context.pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('鍒犻櫎鎴愬姛')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('鍒犻櫎澶辫触: $e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
            child: const Text('鍒犻櫎'),
          ),
        ],
      ),
    );
  }

  /// 閫掑綊娓叉煋宓屽璇勮鍒楄〃
  Widget _buildCommentList(
    List<CommentItem> comments, {
    bool isNested = false,
  }) {
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
          onReply: (c) => setState(() => _replyingTo = c),
          commentKeyBuilder: _commentKeyFor,
          currentUserId: _currentUserId,
          onDelete: _handleDeleteComment,
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    return formatRelativeTime(dateTime);
  }
}

/// 璇勮鍒楄〃椤?
class _CommentTile extends StatefulWidget {
  final CommentItem comment;
  final void Function(CommentItem)? onReply;
  final int indentLevel;
  final GlobalKey Function(String commentId)? commentKeyBuilder;
  final String currentUserId;
  final Future<void> Function(CommentItem comment)? onDelete;

  const _CommentTile({
    required this.comment,
    this.onReply,
    this.indentLevel = 0,
    this.commentKeyBuilder,
    this.currentUserId = '',
    this.onDelete,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLiked;
    _likeCount = widget.comment.likeCount;
  }

  @override
  void didUpdateWidget(_CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id) {
      _isLiked = widget.comment.isLiked;
      _likeCount = widget.comment.likeCount;
    }
  }

  Future<void> _toggleLike(BuildContext context) async {
    final wasLiked = _isLiked;
    // 涔愯鏇存柊
    setState(() {
      _isLiked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
    });
    try {
      final repo = ProviderScope.containerOf(
        context,
      ).read(postRepositoryProvider);
      if (wasLiked) {
        await repo.unlikeComment(widget.comment.id);
      } else {
        await repo.likeComment(widget.comment.id);
      }
    } catch (_) {
      // 鍥炴粴
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount += wasLiked ? 1 : -1;
        });
      }
    }
  }

  bool get _canDelete {
    final String userId = widget.currentUserId.trim();
    return userId.isNotEmpty && userId == widget.comment.authorUserId;
  }

  Future<void> _showActionMenu(LongPressStartDetails details) async {
    HapticFeedback.mediumImpact();
    final media = MediaQuery.of(context);
    final _CommentAction? action = await showMenu<_CommentAction>(
      context: context,
      color: MobileColors.of(context).surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy - 10,
        media.size.width - details.globalPosition.dx,
        media.size.height - details.globalPosition.dy,
      ),
      items: <PopupMenuEntry<_CommentAction>>[
        const PopupMenuItem<_CommentAction>(
          value: _CommentAction.copy,
          child: Text('澶嶅埗'),
        ),
        if (_canDelete && widget.onDelete != null)
          const PopupMenuItem<_CommentAction>(
            value: _CommentAction.delete,
            child: Text('鍒犻櫎', style: TextStyle(color: MobileTheme.error)),
          ),
      ],
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == _CommentAction.copy) {
      await Clipboard.setData(ClipboardData(text: widget.comment.content));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comment copied')));
      return;
    }
    if (action == _CommentAction.delete && _canDelete) {
      await widget.onDelete?.call(widget.comment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final colors = MobileColors.of(context);
    // 澶村儚灏哄锛氭瘡缂╄繘涓€灞傜缉灏?dp锛屾渶澶氱缉鍒?4dp锛堝熀纭€浠?2寮€濮嬶級
    final double avatarRadius = (22 - widget.indentLevel * 2)
        .clamp(14, 22)
        .toDouble();
    // 宸︿晶缂╄繘锛氭瘡灞?0dp锛屾渶澶х缉杩?0dp
    final double leftPadding = (widget.indentLevel * 20)
        .clamp(0, 60)
        .toDouble();
    // 瑙嗚缂╄繘鏈€澶氬睍绀哄埌 3 灞傦紝閬垮厤杩囨繁宓屽鎶婃鏂囨尋娌★紱
    // 浣嗚瘎璁哄唴瀹规湰韬户缁€掑綊娓叉煋锛屼笉鎴柇妤间腑妤笺€?
    final int effectiveIndent = widget.indentLevel.clamp(0, 3);
    final double guideWidth = effectiveIndent * 12.0;

    return Container(
      key: widget.commentKeyBuilder?.call(comment.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPressStart: _showActionMenu,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // 宸︿晶缂╄繘 + 绔栫嚎
                SizedBox(
                  width: leftPadding + (effectiveIndent > 0 ? guideWidth : 16),
                  child: effectiveIndent > 0
                      ? Row(
                          children: [
                            SizedBox(width: leftPadding),
                            ...List.generate(effectiveIndent, (i) {
                              return Container(
                                width: 2,
                                margin: const EdgeInsets.only(right: 10),
                                color: colors.divider,
                              );
                            }),
                          ],
                        )
                      : SizedBox(width: leftPadding),
                ),
                // 澶村儚
                Align(
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: comment.authorUserId.isNotEmpty
                        ? () => context.push('/user/${comment.authorUserId}')
                        : null,
                    child: AvatarWidget(
                      avatarUrl: comment.authorAvatar,
                      nickname: comment.authorAlias,
                      radius: avatarRadius,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 鍐呭
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 鏄电О + 鏃堕棿
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: comment.authorUserId.isNotEmpty
                                  ? () => context.push(
                                      '/user/${comment.authorUserId}',
                                    )
                                  : null,
                              child: Text(
                                comment.authorAlias,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: comment.authorUserId.isNotEmpty
                                      ? MobileTheme.primary
                                      : colors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(comment.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // 姝ｆ枃锛氱偣鍑昏Е鍙戝洖澶?
                      GestureDetector(
                        onTap: () => widget.onReply?.call(comment),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          comment.content,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 搴曢儴鎿嶄綔鏍忥細鐐硅禐 + 鍥炲鏁?
                      Row(
                        children: [
                          // 鐐硅禐
                          GestureDetector(
                            onTap: () => _toggleLike(context),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 18,
                                  color: _isLiked
                                      ? MobileTheme.accent
                                      : colors.textPrimary,
                                ),
                                if (_likeCount > 0) ...[
                                  const SizedBox(width: 3),
                                  Text(
                                    '$_likeCount',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _isLiked
                                          ? MobileTheme.accent
                                          : colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // 鍥炲鏁?
                          GestureDetector(
                            onTap: () => widget.onReply?.call(comment),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                  color: colors.textPrimary,
                                ),
                                if (comment.effectiveReplyCount > 0) ...[
                                  const SizedBox(width: 3),
                                  Text(
                                    '${comment.effectiveReplyCount}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
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
          ),
          // 閫掑綊娓叉煋瀛愬洖澶嶏紱瓒呰繃 3 灞傚悗涓嶅啀澧炲姞瑙嗚缂╄繘锛屼絾缁х画鏄剧ず鍐呭
          if (comment.replies.isNotEmpty)
            ...comment.replies.map(
              (reply) => _CommentTile(
                comment: reply,
                indentLevel: widget.indentLevel + 1,
                onReply: widget.onReply,
                commentKeyBuilder: widget.commentKeyBuilder,
                currentUserId: widget.currentUserId,
                onDelete: widget.onDelete,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return formatRelativeTime(dateTime);
  }
}

/// 搴曢儴鎿嶄綔鎸夐挳
enum _CommentAction { copy, delete }

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isLoading;
  final Color activeColor;
  final VoidCallback onTap;
  final double iconSize;

  const _ActionItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    this.isLoading = false,
    required this.activeColor,
    required this.onTap,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final inactiveColor = colors.textPrimary;
    final Color effectiveColor = isActive ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Row(
        children: [
          isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: inactiveColor,
                  ),
                )
              : Icon(
                  isActive ? activeIcon : icon,
                  size: iconSize,
                  color: effectiveColor,
                ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: effectiveColor,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// 涓炬姤琛ㄥ崟
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

  final _reasons = ['鍨冨溇骞垮憡', '浜鸿韩鏀诲嚮', '鑹叉儏浣庝織', '杩濇硶杩濊', '铏氬亣淇℃伅', '渚电姱闅愮', '鍏朵粬'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('璇烽€夋嫨涓炬姤鍘熷洜')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('涓炬姤澶辫触: $e')));
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
    final colors = MobileColors.of(context);
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
          Text(
            '涓炬姤鍘熷洜',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
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
                        : colors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? MobileTheme.error : colors.divider,
                    ),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? MobileTheme.error
                          : colors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
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
              hintText: '琛ュ厖璇存槑锛堝彲閫夛級',
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
                  : const Text('鎻愪氦涓炬姤'),
            ),
          ),
        ],
      ),
    );
  }
}

