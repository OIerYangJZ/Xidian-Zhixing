import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/auth_store.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/utils/app_date_format.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/comment_item.dart';
import '../../models/post_item.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/emoji/emoji_assistant_bar.dart';
import '../../widgets/image_gallery.dart';
import '../../widgets/post_content_body.dart';
import '../messages/chat_page.dart';
import '../profile/public_user_profile_page.dart';
import '../search/search_page.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.post});

  final PostItem post;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  late PostItem _post;
  List<CommentItem> _comments = const <CommentItem>[];
  String? _replyToCommentId;
  String? _replyToAlias;
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadDetail(recordView: true);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> supplementaryImageUrls = _supplementaryImageUrls(_post);
    final EditorialColors colors = EditorialColors.of(context);
    return Scaffold(
      backgroundColor: colors.page,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: Column(
                children: <Widget>[
                  _DetailPageHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                    onMore: _actionBusy ? null : _openMoreActions,
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ScrollConfiguration(
                            behavior: const _PostDetailScrollBehavior(),
                            child: CustomScrollView(
                              key: const Key('post-detail-scroll'),
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: <Widget>[
                                if (_error != null)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      child: AppInlineMessage(
                                        title: '内容加载失败',
                                        message: _error!,
                                        tone: AppMessageTone.error,
                                        action: TextButton(
                                          onPressed: () => _loadDetail(),
                                          child: const Text('重试'),
                                        ),
                                      ),
                                    ),
                                  ),
                                SliverToBoxAdapter(
                                  child: _PostThreadItem(
                                    post: _post,
                                    imageUrls: supplementaryImageUrls,
                                    commentCount: _countComments(_comments),
                                    actionBusy: _actionBusy,
                                    onOpenAuthor: _openAuthorProfile,
                                    onOpenHashtag: _openHashtag,
                                    onLike: _like,
                                    onComment: _focusComment,
                                    onFavorite: _toggleFavorite,
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: Divider(height: 1, color: colors.line),
                                ),
                                SliverToBoxAdapter(
                                  child: _InlineCommentComposer(
                                    controller: _commentController,
                                    focusNode: _commentFocusNode,
                                    replyToAlias: _replyToAlias,
                                    busy: _actionBusy,
                                    onCancelReply: _replyToCommentId == null
                                        ? null
                                        : () => setState(() {
                                            _replyToCommentId = null;
                                            _replyToAlias = null;
                                          }),
                                    onSubmit: _submitComment,
                                  ),
                                ),
                                if (_comments.isEmpty)
                                  const SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: Text(
                                        '暂无回复',
                                        key: Key('comments-empty-state'),
                                      ),
                                    ),
                                  )
                                else
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (BuildContext context, int index) =>
                                          _CommentThreadTile(
                                            comment: _comments[index],
                                            onReply: _actionBusy
                                                ? null
                                                : (CommentItem comment) =>
                                                      _prepareReply(
                                                        comment: comment,
                                                      ),
                                            onReport: _actionBusy
                                                ? null
                                                : _reportComment,
                                            onOpenAuthor: _openCommentAuthor,
                                          ),
                                      childCount: _comments.length,
                                    ),
                                  ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: AppSpacing.xxxl),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _focusComment() {
    _commentFocusNode.requestFocus();
  }

  Future<void> _openMoreActions() {
    final EditorialColors colors = EditorialColors.of(context);
    return showAppDialog<void>(
      context: context,
      builder: (BuildContext sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_post.canViewAuthorProfile && _post.authorUserId.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('查看主页'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openAuthorProfile();
              },
            ),
          if (_post.canFollowAuthor && _post.authorUserId.isNotEmpty)
            ListTile(
              leading: Icon(
                _post.isFollowingAuthor
                    ? Icons.person_remove_alt_1_outlined
                    : Icons.person_add_alt_1_outlined,
              ),
              title: Text(_post.isFollowingAuthor ? '取消关注' : '关注作者'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _toggleFollowAuthor();
              },
            ),
          if (_post.canMessageAuthor)
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('私信作者'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _requestDm();
              },
            ),
          if (!_post.isMarkdown)
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('复制内容'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _copyPostContent();
              },
            ),
          ListTile(
            leading: Icon(Icons.flag_outlined, color: colors.danger),
            title: Text('举报', style: TextStyle(color: colors.danger)),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _report();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Future<void> _loadDetail({bool recordView = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (recordView) {
        final int? nextViewCount = await AppRepositories.posts.incrementView(
          widget.post.id,
        );
        if (mounted && nextViewCount != null) {
          setState(() {
            _post = _post.copyWith(viewCount: nextViewCount);
          });
        }
      }
      final PostItem detail = await AppRepositories.posts.fetchPostDetail(
        widget.post.id,
      );
      final List<CommentItem> comments = await AppRepositories.posts
          .fetchComments(widget.post.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _post = detail;
        _comments = _buildCommentTree(comments);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<CommentItem> _buildCommentTree(List<CommentItem> flatComments) {
    final Map<String, CommentItem> commentMap = <String, CommentItem>{};
    for (final CommentItem comment in flatComments) {
      commentMap[comment.id] = comment.copyWith(replies: <CommentItem>[]);
    }
    final List<CommentItem> roots = <CommentItem>[];
    for (final CommentItem comment in flatComments) {
      final CommentItem node = commentMap[comment.id]!;
      if (comment.parentId.isEmpty ||
          !commentMap.containsKey(comment.parentId)) {
        roots.add(node);
      } else {
        commentMap[comment.parentId]!.replies.add(node);
      }
    }
    return roots;
  }

  int _countComments(List<CommentItem> comments) {
    int total = 0;
    for (final CommentItem comment in comments) {
      total += 1 + _countComments(comment.replies);
    }
    return total;
  }

  Future<void> _submitComment() async {
    final String content = _commentController.text.trim();
    if (content.isEmpty) {
      _feedback('评论不能为空');
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.posts.createComment(
        postId: _post.id,
        content: content,
        parentId: _replyToCommentId,
      );
      _commentController.clear();
      final List<CommentItem> comments = await AppRepositories.posts
          .fetchComments(_post.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _buildCommentTree(comments);
        _replyToCommentId = null;
        _replyToAlias = null;
      });
      _feedback('评论已发送');
    } catch (error) {
      _feedback('评论失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _like() async {
    await _runAction(
      action: () => AppRepositories.posts.likePost(_post.id),
      success: '已点赞',
    );
  }

  Future<void> _toggleFavorite() async {
    final bool currentFavorited = _post.isFavorited;
    setState(() {
      _actionBusy = true;
    });

    try {
      final FavoriteActionResult result = currentFavorited
          ? await AppRepositories.posts.unfavoritePost(_post.id)
          : await AppRepositories.posts.favoritePost(_post.id);
      if (!mounted) {
        return;
      }

      final int nextCount =
          result.favoriteCount ??
          (result.favorited
              ? (currentFavorited
                    ? _post.favoriteCount
                    : _post.favoriteCount + 1)
              : (currentFavorited
                    ? (_post.favoriteCount > 0 ? _post.favoriteCount - 1 : 0)
                    : _post.favoriteCount));

      setState(() {
        _post = _post.copyWith(
          isFavorited: result.favorited,
          favoriteCount: nextCount,
        );
      });
      _feedback(result.favorited ? '已收藏' : '已取消收藏');
    } catch (error) {
      _feedback('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _report() async {
    final Map<String, dynamic>? result = await _showReportDialog();
    if (result == null) return;

    await _runAction(
      action: () => AppRepositories.posts.report(
        targetType: 'post',
        targetId: _post.id,
        reason: result['reason'] as String,
        description: result['description'] as String?,
      ),
      success: '已提交举报',
    );
  }

  Future<void> _reportComment(String commentId) async {
    final Map<String, dynamic>? result = await _showReportDialog();
    if (result == null) return;

    await _runAction(
      action: () => AppRepositories.posts.report(
        targetType: 'comment',
        targetId: commentId,
        reason: result['reason'] as String,
        description: result['description'] as String?,
      ),
      success: '已举报评论',
    );
  }

  Future<Map<String, dynamic>?> _showReportDialog() async {
    String? selectedReason;
    final TextEditingController descController = TextEditingController();

    final List<String> reasons = <String>[
      '垃圾广告',
      '违法违规',
      '色情低俗',
      '人身攻击',
      '虚假信息',
      '侵犯隐私',
      '其他',
    ];

    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: const Text('举报'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('请选择举报原因：'),
                      const SizedBox(height: 8),
                      ...reasons.map(
                        (String reason) => RadioListTile<String>(
                          title: Text(reason),
                          value: reason,
                          // ignore: deprecated_member_use
                          groupValue: selectedReason,
                          // ignore: deprecated_member_use
                          onChanged: (String? value) {
                            setState(() {
                              selectedReason = value;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        maxLength: 200,
                        minLines: 2,
                        maxLines: 4,
                        decoration: AppInput.decoration(
                          hintText: '补充说明（选填）',
                          counterMaxLength: 200,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: selectedReason == null
                        ? null
                        : () => Navigator.of(context).pop(true),
                    child: const Text('确认举报'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true || selectedReason == null) {
        return null;
      }

      return <String, dynamic>{
        'reason': selectedReason,
        'description': descController.text.trim(),
      };
    } finally {
      descController.dispose();
    }
  }

  Future<void> _copyPostContent() async {
    if (_post.isMarkdown) {
      _feedback('Markdown 帖子不支持复制内容');
      return;
    }
    final String body = _post.isMarkdown ? _post.markdownSource : _post.content;
    final String text = '[${_post.channel}] ${_post.title}\\n$body';
    await Clipboard.setData(ClipboardData(text: text));
    _feedback('已复制帖子内容');
  }

  List<String> _supplementaryImageUrls(PostItem post) {
    if (!post.isMarkdown || post.markdownSource.trim().isEmpty) {
      return post.imageUrls;
    }
    return post.imageUrls
        .where((String url) => !post.markdownSource.contains(url))
        .toList();
  }

  Future<void> _requestDm() async {
    if (_post.authorUserId.isEmpty || !_post.canMessageAuthor) {
      return;
    }
    try {
      setState(() {
        _actionBusy = true;
      });
      final conversation = await AppRepositories.messages
          .createDirectConversation(_post.authorUserId, fromPostId: _post.id);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(
            conversation: conversation,
            peerUserId: _post.authorUserId,
          ),
        ),
      );
    } catch (error) {
      _feedback('无法发起私信：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _toggleFollowAuthor() async {
    if (_post.authorUserId.isEmpty || !_post.canFollowAuthor) {
      return;
    }
    setState(() {
      _actionBusy = true;
    });
    try {
      if (_post.isFollowingAuthor) {
        await AppRepositories.users.unfollowUser(_post.authorUserId);
      } else {
        await AppRepositories.users.followUser(_post.authorUserId);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _post = _post.copyWith(isFollowingAuthor: !_post.isFollowingAuthor);
      });
      _feedback(_post.isFollowingAuthor ? '关注成功' : '已取消关注');
    } catch (error) {
      _feedback('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  void _openAuthorProfile() {
    if (_post.authorUserId.isEmpty) {
      return;
    }
    _openCommentAuthor(_post.authorUserId);
  }

  void _openCommentAuthor(String userId) {
    if (userId.isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfilePage(userId: userId),
      ),
    );
  }

  void _openHashtag(String hashtag) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(initialKeyword: hashtag),
      ),
    );
  }

  void _prepareReply({required CommentItem comment}) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToAlias = comment.authorAlias;
    });
    _commentFocusNode.requestFocus();
    _feedback('已选择回复 ${comment.authorAlias}');
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    required String success,
  }) async {
    setState(() {
      _actionBusy = true;
    });

    try {
      await action();
      _feedback(success);
    } catch (error) {
      _feedback('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  void _feedback(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DetailPageHeader extends StatelessWidget {
  const _DetailPageHeader({required this.onBack, required this.onMore});

  final VoidCallback onBack;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          IconButton(
            onPressed: onMore,
            tooltip: '更多操作',
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }
}

class _PostThreadItem extends StatelessWidget {
  const _PostThreadItem({
    required this.post,
    required this.imageUrls,
    required this.commentCount,
    required this.actionBusy,
    required this.onOpenAuthor,
    required this.onOpenHashtag,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
  });

  final PostItem post;
  final List<String> imageUrls;
  final int commentCount;
  final bool actionBusy;
  final VoidCallback onOpenAuthor;
  final ValueChanged<String> onOpenHashtag;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final EditorialColors colors = EditorialColors.of(context);
    final bool canOpenAuthor =
        post.canViewAuthorProfile && post.authorUserId.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PostAuthorAvatar(
                post: post,
                onTap: canOpenAuthor ? onOpenAuthor : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: GestureDetector(
                        onTap: canOpenAuthor ? onOpenAuthor : null,
                        child: Text(
                          post.isAnonymous ? '匿名同学' : post.authorAlias,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppDateFormat.threadDate(context, post.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.title.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              post.title.trim(),
              style: AppTypography.postContentStyle(
                theme.textTheme.titleLarge,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (post.content.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            PostContentBody(
              content: post.content,
              contentFormat: post.contentFormat,
              markdownSource: post.markdownSource,
              onHashtagTap: onOpenHashtag,
            ),
          ],
          if (imageUrls.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            ImageGallery(images: imageUrls),
          ],
          const SizedBox(height: AppSpacing.md),
          _PostDetailActionBar(
            likeCount: post.likeCount,
            commentCount: commentCount,
            favoriteCount: post.favoriteCount,
            liked: post.isLiked,
            favorited: post.isFavorited,
            enabled: !actionBusy,
            onLike: onLike,
            onComment: onComment,
            onFavorite: onFavorite,
          ),
        ],
      ),
    );
  }
}

class _InlineCommentComposer extends StatelessWidget {
  const _InlineCommentComposer({
    required this.controller,
    required this.focusNode,
    required this.replyToAlias,
    required this.busy,
    required this.onCancelReply,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyToAlias;
  final bool busy;
  final VoidCallback? onCancelReply;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final String nickname =
        AuthStore.instance.currentUser?.nickname.trim().isNotEmpty == true
        ? AuthStore.instance.currentUser!.nickname.trim()
        : '我';
    final String avatarUrl = AppConfig.resolveUrl(
      AuthStore.instance.currentUser?.avatarUrl ?? '',
    );
    final EditorialColors colors = EditorialColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CurrentUserAvatar(nickname: nickname, avatarUrl: avatarUrl),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (replyToAlias != null) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '回复 $replyToAlias',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: busy ? null : onCancelReply,
                        tooltip: '取消回复',
                        icon: const Icon(Icons.close_rounded, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                ],
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  style: AppTypography.postContentStyle(
                    Theme.of(context).textTheme.bodyMedium,
                  ),
                  decoration: AppInput.inlineComposerDecoration(
                    hintText: replyToAlias == null ? '加入讨论…' : '输入回复内容',
                    suffixIcon: IconButton(
                      onPressed: busy ? null : onSubmit,
                      tooltip: '发布回复',
                      icon: Icon(
                        Icons.arrow_upward_rounded,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                EmojiAssistantBar(controller: controller, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentUserAvatar extends StatelessWidget {
  const _CurrentUserAvatar({required this.nickname, required this.avatarUrl});

  final String nickname;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return CircleAvatar(
      radius: 18,
      backgroundColor: colors.primarySubtle,
      foregroundColor: colors.primary,
      backgroundImage: avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
      child: avatarUrl.isEmpty
          ? Text(
              nickname.characters.first,
              style: Theme.of(context).textTheme.labelMedium,
            )
          : null,
    );
  }
}

class _PostDetailScrollBehavior extends MaterialScrollBehavior {
  const _PostDetailScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class _PostAuthorAvatar extends StatelessWidget {
  const _PostAuthorAvatar({required this.post, this.onTap});

  final PostItem post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final String label = post.isAnonymous || post.authorAlias.trim().isEmpty
        ? '匿'
        : post.authorAlias.trim().characters.first;
    final String avatarUrl = AppConfig.resolveUrl(post.authorAvatarUrl);
    final Widget fallback = Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primarySubtle,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: colors.primary),
      ),
    );
    final Widget avatar = post.isAnonymous || avatarUrl.isEmpty
        ? fallback
        : ClipOval(
            child: Image.network(
              avatarUrl,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
          );
    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}

class _PostDetailActionBar extends StatelessWidget {
  const _PostDetailActionBar({
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.liked,
    required this.favorited,
    required this.enabled,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
  });

  final int likeCount;
  final int commentCount;
  final int favoriteCount;
  final bool liked;
  final bool favorited;
  final bool enabled;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _PostDetailAction(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: '$likeCount',
          active: liked,
          onTap: enabled ? onLike : null,
        ),
        const SizedBox(width: AppSpacing.lg),
        _PostDetailAction(
          icon: Icons.mode_comment_outlined,
          label: '$commentCount',
          onTap: onComment,
        ),
        const SizedBox(width: AppSpacing.lg),
        _PostDetailAction(
          icon: favorited
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: '$favoriteCount',
          active: favorited,
          onTap: enabled ? onFavorite : null,
        ),
      ],
    );
  }
}

class _PostDetailAction extends StatefulWidget {
  const _PostDetailAction({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  State<_PostDetailAction> createState() => _PostDetailActionState();
}

class _PostDetailActionState extends State<_PostDetailAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final Color foreground = widget.active ? colors.primary : colors.mutedInk;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: widget.onTap,
      onHighlightChanged: (bool pressed) => setState(() => _pressed = pressed),
      child: AnimatedScale(
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.emphasis,
        scale: _pressed ? 0.9 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(widget.icon, size: 18, color: foreground),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                widget.label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentThreadTile extends StatefulWidget {
  const _CommentThreadTile({
    required this.comment,
    required this.onReply,
    required this.onReport,
    required this.onOpenAuthor,
    this.depth = 0,
  });

  final CommentItem comment;
  final ValueChanged<CommentItem>? onReply;
  final ValueChanged<String>? onReport;
  final ValueChanged<String> onOpenAuthor;
  final int depth;

  @override
  State<_CommentThreadTile> createState() => _CommentThreadTileState();
}

class _CommentThreadTileState extends State<_CommentThreadTile> {
  late bool _isLiked;
  late int _likeCount;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLiked;
    _likeCount = widget.comment.likeCount;
  }

  @override
  void didUpdateWidget(covariant _CommentThreadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id ||
        oldWidget.comment.isLiked != widget.comment.isLiked ||
        oldWidget.comment.likeCount != widget.comment.likeCount) {
      _isLiked = widget.comment.isLiked;
      _likeCount = widget.comment.likeCount;
    }
  }

  Future<void> _toggleLike() async {
    if (_busy) {
      return;
    }
    final bool wasLiked = _isLiked;
    setState(() {
      _busy = true;
      _isLiked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
    });
    try {
      if (wasLiked) {
        await AppRepositories.posts.unlikeComment(widget.comment.id);
      } else {
        await AppRepositories.posts.likeComment(widget.comment.id);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLiked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CommentItem comment = widget.comment;
    final String avatarUrl = AppConfig.resolveUrl(
      (comment.authorAvatar ?? '').trim(),
    );
    final String fallback = comment.authorAlias.trim().isEmpty
        ? '匿'
        : comment.authorAlias.trim().characters.first;
    final ThemeData theme = Theme.of(context);
    final EditorialColors colors = EditorialColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppThreadBranch(
          depth: widget.depth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GestureDetector(
                    onTap: comment.authorUserId.isEmpty
                        ? null
                        : () => widget.onOpenAuthor(comment.authorUserId),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: colors.primarySubtle,
                      foregroundColor: colors.primary,
                      backgroundImage: avatarUrl.isEmpty
                          ? null
                          : NetworkImage(avatarUrl),
                      child: avatarUrl.isEmpty ? Text(fallback) : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: GestureDetector(
                            onTap: comment.authorUserId.isEmpty
                                ? null
                                : () =>
                                      widget.onOpenAuthor(comment.authorUserId),
                            child: Text(
                              comment.authorAlias,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          AppDateFormat.threadDate(context, comment.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.mutedInk,
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          tooltip: '更多操作',
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            size: 18,
                            color: colors.mutedInk,
                          ),
                          onSelected: (String value) {
                            if (value == 'report')
                              widget.onReport?.call(comment.id);
                          },
                          itemBuilder: (BuildContext context) =>
                              const <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'report',
                                  child: Text('举报'),
                                ),
                              ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                comment.content,
                style: AppTypography.postContentStyle(
                  theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: <Widget>[
                  _CommentAction(
                    icon: Icons.reply_outlined,
                    onPressed: widget.onReply == null
                        ? null
                        : () => widget.onReply!(comment),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  _CommentAction(
                    icon: _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    onPressed: _busy ? null : _toggleLike,
                    label: _likeCount == 0 ? null : '$_likeCount',
                    active: _isLiked,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (comment.replies.isNotEmpty)
          ...comment.replies.map(
            (CommentItem reply) => _CommentThreadTile(
              comment: reply,
              depth: widget.depth + 1,
              onReply: widget.onReply,
              onReport: widget.onReport,
              onOpenAuthor: widget.onOpenAuthor,
            ),
          ),
      ],
    );
  }
}

class _CommentAction extends StatefulWidget {
  const _CommentAction({
    required this.icon,
    required this.onPressed,
    this.label,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final bool active;

  @override
  State<_CommentAction> createState() => _CommentActionState();
}

class _CommentActionState extends State<_CommentAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final Color color = widget.active ? colors.primary : colors.mutedInk;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: widget.onPressed,
      onHighlightChanged: (bool value) => setState(() => _pressed = value),
      child: AnimatedScale(
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.emphasis,
        scale: _pressed ? 0.9 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(widget.icon, size: 18, color: color),
              if (widget.label != null) ...<Widget>[
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  widget.label!,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
