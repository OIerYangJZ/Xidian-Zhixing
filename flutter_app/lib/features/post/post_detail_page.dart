import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../design_system/design_system.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/navigation/share_links.dart';
import '../../models/comment_item.dart';
import '../../models/post_item.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/emoji/emoji_assistant_bar.dart';
import '../../widgets/post_card.dart';
import 'report_dialog.dart';
import '../../widgets/image_gallery.dart';
import '../../widgets/post_content_body.dart';
import '../messages/chat_page.dart';
import '../profile/public_user_profile_page.dart';

String _formatDateTime(DateTime value) {
  final DateTime local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

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
    final ZxTokens t = ZxTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: uiText(context, zh: '返回', en: 'Back'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(uiText(context, zh: '帖子详情', en: 'Post')),
        actions: <Widget>[
          Center(
            child: ZxButton(
              label: uiText(context, zh: '复制链接', en: 'Copy link'),
              icon: Icons.link_rounded,
              variant: ZxButtonVariant.outline,
              small: true,
              onPressed: _copyPostLink,
            ),
          ),
          IconButton(
            key: const Key('post-detail-more'),
            tooltip: uiText(context, zh: '更多', en: 'More'),
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: _loading ? null : _openMoreMenu,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ZxPaper(
        child: _loading
            ? const _DetailSkeleton()
            : Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: <Widget>[
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: _buildPost(context, t),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildComposer(context, t),
                ],
              ),
      ),
    );
  }

  Widget _buildPost(BuildContext context, ZxTokens t) {
    final Locale locale = Localizations.localeOf(context);
    final List<String> supplementaryImageUrls = _supplementaryImageUrls(_post);
    final bool canOpenAuthor =
        _post.canViewAuthorProfile && _post.authorUserId.isNotEmpty;
    final String author = _post.isAnonymous
        ? uiText(context, zh: '匿名身份', en: 'Anonymous')
        : _post.authorAliasFor(locale);
    final int commentCount = _countComments(_comments);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ZxInlineMessage(
              message: uiText(
                context,
                zh: '部分内容加载失败：$_error',
                en: 'Some content failed to load: $_error',
              ),
              tone: ZxMessageTone.danger,
              actionLabel: uiText(context, zh: '重试', en: 'Retry'),
              onAction: () => _loadDetail(),
            ),
          ),
        PostMarkers(post: _post),
        const SizedBox(height: 12),
        Text(
          _post.title,
          style: ZxType.titleLarge.copyWith(
            fontSize: 24,
            height: 1.35,
            color: t.text,
          ),
        ),
        const SizedBox(height: 14),
        ZxCard(
          elevation: ZxElevation.flat,
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 10,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _post.isAnonymous
                      ? ZxAvatar.anonymous(name: _post.authorAliasFor(locale))
                      : ZxAvatar(
                          name: author,
                          imageUrl: AppConfig.resolveUrl(
                            _post.authorAvatarUrl.trim(),
                          ),
                          onTap: canOpenAuthor ? _openAuthorProfile : null,
                        ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(author, style: ZxType.label.copyWith(color: t.text)),
                      Text(
                        uiText(
                          context,
                          zh: '${_formatDateTime(_post.createdAt)} · ${_post.viewCount} 阅读',
                          en: '${_formatDateTime(_post.createdAt)} · ${_post.viewCount} views',
                        ),
                        style: ZxType.caption.copyWith(color: t.text3),
                      ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (canOpenAuthor)
                    ZxButton(
                      label: uiText(context, zh: '查看主页', en: 'Profile'),
                      variant: ZxButtonVariant.outline,
                      small: true,
                      onPressed: _openAuthorProfile,
                    ),
                  if (_post.canMessageAuthor)
                    ZxButton(
                      label: uiText(context, zh: '私信作者', en: 'Message'),
                      icon: Icons.forum_outlined,
                      variant: ZxButtonVariant.outline,
                      small: true,
                      onPressed: _actionBusy ? null : _requestDm,
                    ),
                  if (_post.canFollowAuthor && _post.authorUserId.isNotEmpty)
                    ZxButton(
                      label: _post.isFollowingAuthor
                          ? uiText(context, zh: '已关注', en: 'Following')
                          : uiText(context, zh: '关注作者', en: 'Follow'),
                      icon: _post.isFollowingAuthor ? null : Icons.add_rounded,
                      variant: _post.isFollowingAuthor
                          ? ZxButtonVariant.secondary
                          : ZxButtonVariant.primary,
                      small: true,
                      onPressed: _actionBusy ? null : _toggleFollowAuthor,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        DefaultTextStyle.merge(
          style: ZxType.body.copyWith(
            color: t.text,
            fontSize: 16,
            height: 1.75,
          ),
          child: PostContentBody(
            content: _post.content,
            contentFormat: _post.contentFormat,
            markdownSource: _post.markdownSource,
            selectable: !_post.isMarkdown,
          ),
        ),
        if (_post.tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: <Widget>[
              for (final String tag in _post.tags)
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
        if (supplementaryImageUrls.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          ImageGallery(images: supplementaryImageUrls),
        ],
        if (_post.hasImage && supplementaryImageUrls.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              uiText(
                context,
                zh: '图片暂时不可用，请稍后重试',
                en: 'Images are temporarily unavailable. Please try again later.',
              ),
              style: ZxType.caption.copyWith(color: t.text3),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            PostActionPill(
              icon: _post.isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              count: _post.likeCount,
              active: _post.isLiked,
              activeColor: t.primary,
              activeFill: t.primarySoft,
              label: uiText(context, zh: '点赞', en: 'Like'),
              onTap: _actionBusy ? null : _like,
            ),
            PostActionPill(
              icon: _post.isFavorited
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              count: _post.favoriteCount,
              active: _post.isFavorited,
              activeColor: t.accentInk,
              activeFill: t.accentSoft,
              label: uiText(context, zh: '收藏', en: 'Save'),
              onTap: _actionBusy ? null : _toggleFavorite,
            ),
            const Spacer(),
            if (!_post.isMarkdown)
              ZxButton(
                label: uiText(context, zh: '复制内容', en: 'Copy text'),
                icon: Icons.copy_rounded,
                variant: ZxButtonVariant.ghost,
                small: true,
                onPressed: _copyPostContent,
              ),
            ZxButton(
              label: uiText(context, zh: '举报', en: 'Report'),
              icon: Icons.flag_outlined,
              variant: ZxButtonVariant.ghost,
              small: true,
              onPressed: _actionBusy ? null : _report,
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            Text(
              uiText(context, zh: '评论区', en: 'Comments'),
              style: ZxType.title.copyWith(color: t.text),
            ),
            const SizedBox(width: 8),
            Text('$commentCount', style: ZxType.label.copyWith(color: t.text3)),
          ],
        ),
        const SizedBox(height: 10),
        if (_comments.isEmpty)
          ZxCard(
            key: const Key('comments-empty-state'),
            elevation: ZxElevation.flat,
            child: ZxStatePanel(
              icon: Icons.chat_bubble_outline_rounded,
              title: uiText(context, zh: '还没有评论', en: 'No comments yet'),
              message: uiText(
                context,
                zh: '欢迎留下第一条友善、具体的回复。',
                en: 'Be the first to leave a kind, specific reply.',
              ),
            ),
          )
        else
          ZxCard(
            elevation: ZxElevation.flat,
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < _comments.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 1, color: t.line),
                  _CommentThreadTile(
                    comment: _comments[i],
                    floorLabel: uiText(
                      context,
                      zh: '${i + 1} 楼',
                      en: '#${i + 1}',
                    ),
                    onReply: _actionBusy
                        ? null
                        : (CommentItem comment) =>
                              _prepareReply(comment: comment),
                    onReport: _actionBusy
                        ? null
                        : (String commentId) => _reportComment(commentId),
                    onOpenAuthor: _openCommentAuthor,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildComposer(BuildContext context, ZxTokens t) {
    return ZxGlass(
      border: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.line)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_replyToCommentId != null && _replyToAlias != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: <Widget>[
                            Container(width: 3, height: 16, color: t.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                uiText(
                                  context,
                                  zh: '正在回复 $_replyToAlias',
                                  en: 'Replying to $_replyToAlias',
                                ),
                                style: ZxType.caption.copyWith(color: t.text2),
                              ),
                            ),
                            IconButton(
                              onPressed: _actionBusy
                                  ? null
                                  : () => setState(() {
                                      _replyToCommentId = null;
                                      _replyToAlias = null;
                                    }),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              visualDensity: VisualDensity.compact,
                              tooltip: uiText(
                                context,
                                zh: '取消回复',
                                en: 'Cancel reply',
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _replyToCommentId == null
                            ? uiText(
                                context,
                                zh: '发表评论（支持楼中楼回复）',
                                en: 'Write a comment (threaded replies supported)',
                              )
                            : uiText(
                                context,
                                zh: '输入回复内容',
                                en: 'Write your reply',
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        EmojiAssistantBar(
                          controller: _commentController,
                          compact: true,
                        ),
                        const Spacer(),
                        ZxButton(
                          label: uiText(
                            context,
                            zh: '发送评论',
                            en: 'Post comment',
                          ),
                          icon: Icons.send_rounded,
                          loading: _actionBusy,
                          small: true,
                          onPressed: _submitComment,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMoreMenu() async {
    final String? action = await zxShowActionSheet<String>(
      context,
      cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
      actions: <ZxSheetAction<String>>[
        ZxSheetAction<String>(
          value: 'link',
          label: uiText(context, zh: '复制链接', en: 'Copy link'),
          icon: Icons.link_rounded,
        ),
        if (!_post.isMarkdown)
          ZxSheetAction<String>(
            value: 'text',
            label: uiText(context, zh: '复制内容', en: 'Copy text'),
            icon: Icons.copy_rounded,
          ),
        ZxSheetAction<String>(
          value: 'report',
          label: uiText(context, zh: '举报', en: 'Report'),
          icon: Icons.flag_outlined,
        ),
      ],
    );
    switch (action) {
      case 'link':
        await _copyPostLink();
      case 'text':
        await _copyPostContent();
      case 'report':
        await _report();
    }
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
        _error = uiTextGlobal(zh: '加载失败：$error', en: 'Load failed: $error');
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
      _feedback(uiTextGlobal(zh: '评论不能为空', en: 'A comment cannot be empty'));
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
      _feedback(uiTextGlobal(zh: '评论已发送', en: 'Comment posted'));
    } catch (error) {
      _feedback(
        uiTextGlobal(zh: '评论失败：$error', en: 'Could not post comment: $error'),
      );
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
      success: uiTextGlobal(zh: '已点赞', en: 'Liked'),
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
      _feedback(
        result.favorited
            ? uiTextGlobal(zh: '已收藏', en: 'Saved to favorites')
            : uiTextGlobal(zh: '已取消收藏', en: 'Removed from favorites'),
      );
    } catch (error) {
      _feedback(uiTextGlobal(zh: '操作失败：$error', en: 'Action failed: $error'));
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _report() async {
    final ReportChoice? choice = await showReportDialog(context);
    if (choice == null) return;

    await _runAction(
      action: () => AppRepositories.posts.report(
        targetType: 'post',
        targetId: _post.id,
        reason: choice.reason,
        description: choice.description,
      ),
      success: uiTextGlobal(zh: '已提交举报', en: 'Report submitted'),
    );
  }

  Future<void> _reportComment(String commentId) async {
    final ReportChoice? choice = await showReportDialog(context);
    if (choice == null) return;

    await _runAction(
      action: () => AppRepositories.posts.report(
        targetType: 'comment',
        targetId: commentId,
        reason: choice.reason,
        description: choice.description,
      ),
      success: uiTextGlobal(zh: '已举报评论', en: 'Comment reported'),
    );
  }

  Future<void> _copyPostContent() async {
    if (_post.isMarkdown) {
      _feedback(
        uiTextGlobal(
          zh: 'Markdown 帖子不支持复制内容',
          en: 'Copying is not supported for Markdown posts',
        ),
      );
      return;
    }
    final String body = _post.isMarkdown ? _post.markdownSource : _post.content;
    final String text = '[${_post.channel}] ${_post.title}\n$body';
    await Clipboard.setData(ClipboardData(text: text));
    _feedback(uiTextGlobal(zh: '已复制帖子内容', en: 'Post content copied'));
  }

  Future<void> _copyPostLink() async {
    await Clipboard.setData(ClipboardData(text: ShareLink.post(_post.id).url));
    _feedback(uiTextGlobal(zh: '已复制帖子链接', en: 'Post link copied'));
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
      _feedback(
        uiTextGlobal(
          zh: '无法发起私信：$error',
          en: 'Could not start a direct message: $error',
        ),
      );
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
      _feedback(
        _post.isFollowingAuthor
            ? uiTextGlobal(zh: '关注成功', en: 'Following')
            : uiTextGlobal(zh: '已取消关注', en: 'Unfollowed'),
      );
    } catch (error) {
      _feedback(uiTextGlobal(zh: '操作失败：$error', en: 'Action failed: $error'));
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

  void _prepareReply({required CommentItem comment}) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToAlias = comment.authorAliasFor(appLocale);
    });
    _commentFocusNode.requestFocus();
    _feedback(
      uiTextGlobal(
        zh: '已选择回复 ${comment.authorAliasFor(appLocale)}',
        en: 'Replying to ${comment.authorAliasFor(appLocale)}',
      ),
    );
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
      _feedback(uiTextGlobal(zh: '操作失败：$error', en: 'Action failed: $error'));
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

class _CommentThreadTile extends StatefulWidget {
  const _CommentThreadTile({
    required this.comment,
    required this.onReply,
    required this.onReport,
    required this.onOpenAuthor,
    this.floorLabel,
    this.depth = 0,
  });

  final CommentItem comment;
  final ValueChanged<CommentItem>? onReply;
  final ValueChanged<String>? onReport;
  final ValueChanged<String> onOpenAuthor;
  final String? floorLabel;
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
    final ZxTokens t = ZxTokens.of(context);
    final CommentItem comment = widget.comment;
    final Locale locale = Localizations.localeOf(context);
    final String authorAlias = comment.authorAliasFor(locale);
    final bool canOpen =
        !comment.isAnonymous && comment.authorUserId.isNotEmpty;
    final double avatarSize = widget.depth == 0 ? 36 : 28;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.depth == 0 ? 16 : 0,
        14,
        12,
        widget.depth == 0 ? 12 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              comment.isAnonymous
                  ? ZxAvatar.anonymous(name: authorAlias, size: avatarSize)
                  : ZxAvatar(
                      name: authorAlias,
                      imageUrl: (comment.authorAvatar ?? '').trim(),
                      size: avatarSize,
                      onTap: canOpen
                          ? () => widget.onOpenAuthor(comment.authorUserId)
                          : null,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        GestureDetector(
                          onTap: canOpen
                              ? () => widget.onOpenAuthor(comment.authorUserId)
                              : null,
                          child: Text(
                            authorAlias,
                            style: ZxType.label.copyWith(color: t.text),
                          ),
                        ),
                        if (comment.isPostAuthor)
                          ZxBadge.author(uiText(context, zh: '洞主', en: 'OP')),
                        if (comment.isAnonymous)
                          ZxBadge.anonymous(
                            uiText(context, zh: '匿名', en: 'Anonymous'),
                          ),
                        Text(
                          <String>[
                            if (widget.floorLabel != null) widget.floorLabel!,
                            _formatDateTime(comment.createdAt),
                          ].join(' · '),
                          style: ZxType.caption.copyWith(
                            color: t.text3,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.content,
                      style: ZxType.body.copyWith(color: t.text, height: 1.6),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        _CommentAction(
                          label: uiText(context, zh: '回复', en: 'Reply'),
                          onTap: widget.onReply == null
                              ? null
                              : () => widget.onReply!(comment),
                        ),
                        _CommentAction(
                          icon: _isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: '$_likeCount',
                          color: _isLiked ? t.primary : null,
                          onTap: _busy ? null : _toggleLike,
                        ),
                        _CommentAction(
                          label: uiText(context, zh: '举报', en: 'Report'),
                          onTap: widget.onReport == null
                              ? null
                              : () => widget.onReport!(comment.id),
                        ),
                      ],
                    ),
                    if (comment.replies.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: t.line, width: 2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            for (final CommentItem reply in comment.replies)
                              _CommentThreadTile(
                                comment: reply,
                                depth: widget.depth + 1,
                                onReply: widget.onReply,
                                onReport: widget.onReport,
                                onOpenAuthor: widget.onOpenAuthor,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentAction extends StatelessWidget {
  const _CommentAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Color fg = color ?? t.text3;
    return InkWell(
      onTap: onTap,
      borderRadius: ZxRadius.smallButtonAll,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 14, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: ZxType.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ZxSkeleton(width: 160),
              SizedBox(height: 16),
              ZxSkeleton(height: 26),
              SizedBox(height: 18),
              ZxSkeleton(height: 64, borderRadius: ZxRadius.cardAll),
              SizedBox(height: 18),
              ZxSkeleton(),
              SizedBox(height: 10),
              ZxSkeleton(),
              SizedBox(height: 10),
              ZxSkeleton(width: 280),
            ],
          ),
        ),
      ),
    );
  }
}
