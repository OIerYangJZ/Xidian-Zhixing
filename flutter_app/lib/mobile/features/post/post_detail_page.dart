import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xdu_treehole_web/core/auth/auth_store.dart';

import '../../../design_system/design_system.dart';
import '../widgets/avatar_widget.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/utils/post_share.dart';
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

class _PostDetailPageState extends ConsumerState<PostDetailPage>
    with WidgetsBindingObserver {
  PostItem? _post;
  bool _postIsLiked = false;
  List<CommentItem> _comments = [];
  CommentSort _commentSort = CommentSort.hot;
  bool _isLoading = true;
  String? _error;
  bool _isLiking = false;
  bool _isFavoriting = false;
  bool _isPostingComment = false;
  bool _isSortingComments = false;
  bool _isFollowing = false;
  bool _isDeletingComment = false;
  bool _showEmoji = false;
  bool _pendingShowEmojiPanel = false;

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
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialCommentId = (widget.initialCommentId ?? '').trim();
    _ensureCurrentUserLoaded();
    _loadData(recordView: true);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted || !_pendingShowEmojiPanel) {
      return;
    }
    if (_keyboardInset > 0) {
      return;
    }
    _pendingShowEmojiPanel = false;
    if (_showEmoji) {
      return;
    }
    setState(() {
      _showEmoji = true;
    });
  }

  String get _currentUserId => AuthStore.instance.currentUser?.userId ?? '';

  double get _keyboardInset {
    final FlutterView? view = View.maybeOf(context);
    if (view != null) {
      return view.viewInsets.bottom / view.devicePixelRatio;
    }
    final Iterable<FlutterView> views =
        WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return 0;
    }
    final FlutterView fallbackView = views.first;
    return fallbackView.viewInsets.bottom / fallbackView.devicePixelRatio;
  }

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
      final comments = await postRepo.fetchComments(
        widget.postId,
        sort: _commentSort,
      );

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
      // copyWith keeps every field (isPostAuthor, isAnonymous, …).
      map[c.id] = c.copyWith(replies: <CommentItem>[]);
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
    return _sortCommentTree(roots, _commentSort);
  }

  List<CommentItem> _sortCommentTree(
    List<CommentItem> comments,
    CommentSort sort,
  ) {
    final List<CommentItem> sorted = comments.map((CommentItem comment) {
      if (comment.replies.isEmpty) {
        return comment;
      }
      return comment.copyWith(replies: _sortCommentTree(comment.replies, sort));
    }).toList();

    sorted.sort(
      (CommentItem a, CommentItem b) => _compareCommentsForDisplay(a, b, sort),
    );
    return sorted;
  }

  int _compareCommentsForDisplay(
    CommentItem a,
    CommentItem b,
    CommentSort sort,
  ) {
    switch (sort) {
      case CommentSort.hot:
        final int byHot = _commentHotScore(b).compareTo(_commentHotScore(a));
        if (byHot != 0) {
          return byHot;
        }
        final int byLikes = b.likeCount.compareTo(a.likeCount);
        if (byLikes != 0) {
          return byLikes;
        }
        final int byReplies = b.effectiveReplyCount.compareTo(
          a.effectiveReplyCount,
        );
        if (byReplies != 0) {
          return byReplies;
        }
        final int byCreated = b.createdAt.compareTo(a.createdAt);
        if (byCreated != 0) {
          return byCreated;
        }
        return b.id.compareTo(a.id);
      case CommentSort.latest:
        final int byCreated = b.createdAt.compareTo(a.createdAt);
        if (byCreated != 0) {
          return byCreated;
        }
        return b.id.compareTo(a.id);
    }
  }

  int _commentHotScore(CommentItem comment) {
    return (comment.likeCount * 3) + (comment.effectiveReplyCount * 2);
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
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
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
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
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
      ).showSnackBar(const SnackBar(content: Text('举报成功，我们会尽快处理')));
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
      final comments = await postRepo.fetchComments(
        widget.postId,
        sort: _commentSort,
      );

      // 涔愯鏇存柊甯栧瓙璇勮鏁?
      if (mounted && _post != null) {
        setState(() {
          _post = _post!.copyWith(commentCount: _post!.commentCount + 1);
          _comments = _buildCommentTree(comments);
          _replyingTo = null; // 娓呯┖鍥炲鐘舵€?
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('评论成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('评论失败: $e')));
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
      ).showSnackBar(SnackBar(content: Text('无法发起私信: $e')));
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
      ).showSnackBar(const SnackBar(content: Text('关注成功')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
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
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('删除评论'),
            content: const Text('确认删除这条评论吗？删除后不可恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  '删除',
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
      ).showSnackBar(const SnackBar(content: Text('评论已删除')));
      await _loadData(recordView: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
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
    final bool keyboardVisible = _keyboardInset > 0;
    if (_showEmoji) {
      _pendingShowEmojiPanel = false;
      setState(() {
        _showEmoji = false;
      });
      return;
    }
    if (keyboardVisible) {
      _pendingShowEmojiPanel = true;
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    _pendingShowEmojiPanel = false;
    setState(() {
      _showEmoji = true;
    });
  }

  void _handleCommentInputFocusChanged(bool hasFocus) {
    if (hasFocus) {
      _pendingShowEmojiPanel = false;
      if (_showEmoji) {
        setState(() {
          _showEmoji = false;
        });
      }
      return;
    }
  }

  void _handleCommentInputTap() {
    _pendingShowEmojiPanel = false;
    if (_showEmoji) {
      setState(() {
        _showEmoji = false;
      });
    }
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
    final ZxTokens t = ZxTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _SquareAction(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: '返回',
            onTap: () => context.pop(),
          ),
        ),
        leadingWidth: 60,
        titleSpacing: 4,
        title: const Text('帖子详情'),
        actions: [
          if (_post != null) ...[
            _SquareAction(
              key: const Key('mobile-post-copy-link'),
              icon: Icons.link_rounded,
              tooltip: '复制链接',
              onTap: _copyLink,
            ),
            const SizedBox(width: 8),
            _SquareAction(
              icon: Icons.more_horiz,
              tooltip: '更多',
              onTap: _showOptionsSheet,
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorView()
          : _post == null
          ? _buildEmptyView()
          : _buildContent(),
      bottomNavigationBar: _post == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: t.surface,
                border: Border(top: BorderSide(color: t.line)),
              ),
              child: SafeArea(
                top: false,
                child: _post!.allowComment
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_replyingTo != null) _buildReplyBanner(),
                          _buildBottomBarWithEmoji(),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '作者关闭了评论',
                                style: ZxType.body.copyWith(color: t.text3),
                              ),
                            ),
                            ..._buildBottomActions(),
                          ],
                        ),
                      ),
              ),
            ),
    );
  }

  Future<void> _copyLink() async {
    await copyPostShareLink(widget.postId);
    if (!mounted) return;
    zxShowToast(context, '已复制帖子链接');
  }

  Widget _buildBottomBarWithEmoji() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommentInputBar(
            key: _commentInputKey,
            onSubmit: _handleSubmitComment,
            autofocus: false,
            scrollController: _scrollController,
            onEmojiToggle: _toggleEmoji,
            onFocusChanged: _handleCommentInputFocusChanged,
            onTextFieldTap: _handleCommentInputTap,
            trailing: _buildBottomActions(),
          ),
          ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: _showEmoji ? 200 : 0,
              child: _showEmoji
                  ? EmojiPickerBar(onEmojiTap: _onEmojiTap)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: MobileTheme.primaryWithAlpha(context, 0.08),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: MobileTheme.primaryOf(context)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '回复 @${_replyingTo!.authorAlias}',
              style: TextStyle(
                fontSize: 13,
                color: MobileTheme.primaryOf(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyingTo = null),
            child: Icon(
              Icons.close,
              size: 16,
              color: MobileTheme.primaryOf(context),
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
            ElevatedButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final colors = MobileColors.of(context);
    return Center(
      child: Text('帖子不存在或已被删除', style: TextStyle(color: colors.textSecondary)),
    );
  }

  Widget _buildContent() {
    final ZxTokens t = ZxTokens.of(context);
    return RefreshIndicator(
      onRefresh: _loadData,
      color: t.primary,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostContent(),
            Divider(height: 1, indent: 20, endIndent: 20, color: t.line),
            _buildCommentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostContent() {
    final ZxTokens t = ZxTokens.of(context);
    final post = _post!;
    final List<String> supplementaryImageUrls = _supplementaryImageUrls(post);
    final bool canOpenAuthor =
        !post.isAnonymous && post.authorUserId.isNotEmpty && !post.isOwnPost;
    final bool canDm = post.canMessageAuthor && post.authorUserId.isNotEmpty;
    final bool canFollow =
        post.canFollowAuthor &&
        post.authorUserId.isNotEmpty &&
        !post.isFollowingAuthor;
    final Widget? statusBadge = switch (post.status) {
      PostStatus.resolved => const ZxBadge.resolved('已解决'),
      PostStatus.closed => const ZxBadge.closed('已结束'),
      PostStatus.ongoing => null,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: canOpenAuthor
                    ? () => context.push('/user/${post.authorUserId}')
                    : null,
                child: post.isAnonymous
                    ? ZxAvatar.anonymous(name: post.authorAlias, size: 46)
                    : AvatarWidget(
                        avatarUrl: post.authorAvatarUrl,
                        nickname: post.authorAlias,
                        radius: 23,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.authorAlias,
                            style: ZxType.label.copyWith(color: t.text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (post.isAnonymous) ...[
                          const SizedBox(width: 6),
                          const ZxBadge.anonymous('匿名'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.viewCount > 0
                          ? '${_formatTime(post.createdAt)} · ${post.viewCount} 阅读'
                          : _formatTime(post.createdAt),
                      style: ZxType.caption.copyWith(color: t.text3),
                    ),
                  ],
                ),
              ),
              ?statusBadge,
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (post.isPinned) const ZxBadge.pinned('置顶'),
                    ZxBadge.channel(
                      post.channel,
                      color: t.channelFor(post.channel),
                    ),
                  ],
                ),
              ),
              if (canDm)
                ZxButton(
                  label: '私信',
                  small: true,
                  variant: ZxButtonVariant.ghost,
                  onPressed: _handleDm,
                ),
              if (canFollow)
                ZxButton(
                  key: const Key('mobile-post-follow'),
                  label: '关注',
                  small: true,
                  variant: ZxButtonVariant.outline,
                  loading: _isFollowing,
                  onPressed: _handleFollowAuthor,
                ),
            ],
          ),
          if (post.title.isNotEmpty) ...[
            const SizedBox(height: 14),
            SelectableText(
              post.title,
              style: ZxType.title.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: t.text,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          DefaultTextStyle.merge(
            style: ZxType.body.copyWith(
              fontSize: 16,
              color: t.text2,
              height: 1.7,
            ),
            child: PostContentBody(
              content: post.content,
              contentFormat: post.contentFormat,
              markdownSource: post.markdownSource,
              selectable: true,
            ),
          ),
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final String tag in post.tags)
                  Text(
                    '#$tag',
                    style: ZxType.body.copyWith(
                      color: t.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
          if (post.hasImage && supplementaryImageUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            PostImageGrid(imageUrls: supplementaryImageUrls),
          ],
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

  Future<void> _changeCommentSort(CommentSort nextSort) async {
    if (_isSortingComments || _commentSort == nextSort) {
      return;
    }
    final previousSort = _commentSort;
    setState(() {
      _commentSort = nextSort;
      _isSortingComments = true;
    });
    try {
      final comments = await ref
          .read(postRepositoryProvider)
          .fetchComments(widget.postId, sort: nextSort);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _buildCommentTree(comments);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _commentSort = previousSort;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('切换排序失败: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSortingComments = false;
        });
      }
    }
  }

  Future<void> _showCommentSortMenu(TapDownDetails details) async {
    if (_isSortingComments) {
      return;
    }
    _pendingShowEmojiPanel = false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_showEmoji) {
      setState(() {
        _showEmoji = false;
      });
    }
    final colors = MobileColors.of(context);
    final size = MediaQuery.sizeOf(context);
    final double left = (details.globalPosition.dx - 44).clamp(
      12,
      size.width - 140,
    );
    final double top = details.globalPosition.dy + 8;
    final RelativeRect position = RelativeRect.fromLTRB(
      left,
      top,
      size.width - (left + 128),
      0,
    );
    final CommentSort? selected = await showMenu<CommentSort>(
      context: context,
      position: position,
      color: colors.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: <PopupMenuEntry<CommentSort>>[
        PopupMenuItem<CommentSort>(
          value: CommentSort.hot,
          child: _buildSortMenuItem(
            label: '热度',
            selected: _commentSort == CommentSort.hot,
          ),
        ),
        PopupMenuItem<CommentSort>(
          value: CommentSort.latest,
          child: _buildSortMenuItem(
            label: '时间',
            selected: _commentSort == CommentSort.latest,
          ),
        ),
      ],
    );
    if (selected != null) {
      await _changeCommentSort(selected);
    }
  }

  Widget _buildSortMenuItem({required String label, required bool selected}) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: MobileTheme.primaryOf(context),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String get _commentSortLabel => _commentSort == CommentSort.hot ? '热度' : '时间';

  Widget _buildCommentsSection() {
    final ZxTokens t = ZxTokens.of(context);
    final int count = _post?.commentCount ?? _comments.length;
    return Column(
      key: _commentsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text('评论', style: ZxType.title.copyWith(color: t.text)),
              const SizedBox(width: 6),
              Text('$count', style: ZxType.title.copyWith(color: t.text3)),
              const Spacer(),
              if (_isSortingComments)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.text3,
                    ),
                  ),
                ),
              GestureDetector(
                key: const Key('mobile-post-comment-sort'),
                behavior: HitTestBehavior.opaque,
                onTapDown: _showCommentSortMenu,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                  decoration: BoxDecoration(
                    color: t.bgSunk,
                    borderRadius: ZxRadius.buttonAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _commentSortLabel,
                        style: ZxType.caption.copyWith(
                          fontSize: 13,
                          color: t.text2,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: t.text3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '还没有评论，来说第一句吧',
                style: ZxType.body.copyWith(color: t.text3),
              ),
            ),
          )
        else
          _buildCommentList(_comments),
      ],
    );
  }

  /// Like, favorite and share beside the comment field (handoff A2).
  List<Widget> _buildBottomActions() {
    final post = _post!;
    return <Widget>[
      _BarAction(
        key: const Key('mobile-post-like'),
        icon: _postIsLiked ? Icons.favorite_rounded : Icons.favorite_border,
        count: post.likeCount,
        active: _postIsLiked,
        filled: true,
        loading: _isLiking,
        onTap: _handleLike,
      ),
      _BarAction(
        key: const Key('mobile-post-favorite'),
        icon: post.isFavorited ? Icons.star_rounded : Icons.star_border_rounded,
        count: post.favoriteCount,
        active: post.isFavorited,
        loading: _isFavoriting,
        onTap: _handleFavorite,
      ),
      _BarAction(icon: Icons.ios_share_rounded, onTap: _copyLink),
    ];
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
              title: const Text('举报'),
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
        content: const Text('确认删除这篇帖子吗？此操作不可恢复。'),
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('删除成功')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
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
  Widget _buildCommentList(
    List<CommentItem> comments, {
    bool isNested = false,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      separatorBuilder: (_, _) => const SizedBox.shrink(),
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Padding(
          padding: EdgeInsets.zero,
          child: _CommentTile(
            comment: comment,
            indentLevel: isNested ? 1 : 0,
            onReply: (c) => setState(() => _replyingTo = c),
            commentKeyBuilder: _commentKeyFor,
            currentUserId: _currentUserId,
            onDelete: _handleDeleteComment,
            postAuthorId: _post?.authorUserId ?? '',
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    return formatRelativeTime(dateTime);
  }
}

/// 评论列表项
class _CommentTile extends StatefulWidget {
  final CommentItem comment;
  final void Function(CommentItem)? onReply;
  final int indentLevel;
  final GlobalKey Function(String commentId)? commentKeyBuilder;
  final String currentUserId;
  final Future<void> Function(CommentItem comment)? onDelete;
  final String postAuthorId;

  const _CommentTile({
    required this.comment,
    this.onReply,
    this.indentLevel = 0,
    this.commentKeyBuilder,
    this.currentUserId = '',
    this.onDelete,
    this.postAuthorId = '',
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
          child: Text('复制'),
        ),
        if (_canDelete && widget.onDelete != null)
          const PopupMenuItem<_CommentAction>(
            value: _CommentAction.delete,
            child: Text('删除', style: TextStyle(color: MobileTheme.error)),
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
      ).showSnackBar(const SnackBar(content: Text('已复制评论内容')));
      return;
    }
    if (action == _CommentAction.delete && _canDelete) {
      await widget.onDelete?.call(widget.comment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final comment = widget.comment;
    final int indent = widget.indentLevel.clamp(0, 3);
    final double avatarSize = indent == 0 ? 34 : 28;
    final bool isPostAuthor =
        comment.isPostAuthor ||
        (widget.postAuthorId.isNotEmpty &&
            comment.authorUserId == widget.postAuthorId);
    final bool hasAvatar =
        comment.authorAvatar != null && comment.authorAvatar!.isNotEmpty;
    final VoidCallback? openAuthor = comment.authorUserId.isNotEmpty
        ? () => context.push('/user/${comment.authorUserId}')
        : null;
    final TextStyle meta = ZxType.caption.copyWith(color: t.text3);

    final Widget row = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: _showActionMenu,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.0 + indent * 42, 10, 20, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openAuthor,
              child: hasAvatar
                  ? AvatarWidget(
                      avatarUrl: comment.authorAvatar,
                      nickname: comment.authorAlias,
                      radius: avatarSize / 2,
                    )
                  : ZxAvatar.anonymous(
                      name: comment.authorAlias,
                      size: avatarSize,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: openAuthor,
                          child: Text(
                            comment.authorAlias,
                            style: ZxType.label.copyWith(
                              fontSize: 13,
                              color: t.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (isPostAuthor) ...[
                        const SizedBox(width: 6),
                        const ZxBadge.author('洞主'),
                      ],
                      const SizedBox(width: 6),
                      Text(_formatTime(comment.createdAt), style: meta),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => widget.onReply?.call(comment),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      comment.content,
                      style: ZxType.body.copyWith(
                        fontSize: 15,
                        color: t.text,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => widget.onReply?.call(comment),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            comment.effectiveReplyCount > 0
                                ? '回复 ${comment.effectiveReplyCount}'
                                : '回复',
                            style: meta,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: () => _toggleLike(context),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 15,
                                color: _isLiked ? t.primary : t.text3,
                              ),
                              if (_likeCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '$_likeCount',
                                  style: meta.copyWith(
                                    color: _isLiked ? t.primary : t.text3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      key: widget.commentKeyBuilder?.call(comment.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        // 超过 3 层后不再增加缩进，但继续显示内容
        for (final CommentItem reply in comment.replies)
          _CommentTile(
            comment: reply,
            indentLevel: widget.indentLevel + 1,
            onReply: widget.onReply,
            commentKeyBuilder: widget.commentKeyBuilder,
            currentUserId: widget.currentUserId,
            onDelete: widget.onDelete,
            postAuthorId: widget.postAuthorId,
          ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    return formatRelativeTime(dateTime);
  }
}

/// 搴曢儴鎿嶄綔鎸夐挳
enum _CommentAction { copy, delete }

/// The rounded-square app-bar button of handoff A2.
class _SquareAction extends StatelessWidget {
  const _SquareAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Center(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: ZxRadius.buttonAll,
            side: BorderSide(color: t.line),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: ZxRadius.buttonAll,
            ),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 20, color: t.text),
            ),
          ),
        ),
      ),
    );
  }
}

/// A like / favorite / share control in the comment bar. [filled] gives the
/// active state a soft pill, as the like has in the handoff.
class _BarAction extends StatelessWidget {
  const _BarAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.count = 0,
    this.active = false,
    this.filled = false,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int count;
  final bool active;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Color color = active ? t.primary : t.text2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active && filled ? t.primarySoft : null,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: color),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: ZxType.label.copyWith(
                  fontSize: 13,
                  color: color,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
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

  final _reasons = ['垃圾广告', '人身攻击', '色情低俗', '违法违规', '虚假信息', '侵犯隐私', '其他'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择举报原因')));
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
        ).showSnackBar(SnackBar(content: Text('举报失败: $e')));
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
            '举报原因',
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
