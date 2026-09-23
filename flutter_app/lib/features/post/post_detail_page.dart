import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/navigation/post_link.dart';
import '../../core/theme/design_tokens.dart';
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
    final Locale locale = Localizations.localeOf(context);
    final List<String> supplementaryImageUrls = _supplementaryImageUrls(_post);
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: <Widget>[
          IconButton(
            tooltip: uiText(context, zh: '返回', en: 'Back'),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth,
          ),
          child: _loading
              ? AppStatePanel(
                  icon: Icons.hourglass_top_rounded,
                  title: uiText(context, zh: '正在加载帖子', en: 'Loading post'),
                  message: uiText(
                    context,
                    zh: '正文和评论即将呈现。',
                    en: 'The body and comments will appear shortly.',
                  ),
                )
              : ListView(
                  padding: AppLayout.pagePadding(context),
                  children: <Widget>[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppInlineMessage(
                          title: uiText(
                            context,
                            zh: '部分内容加载失败',
                            en: 'Some content failed to load',
                          ),
                          message: _error!,
                          tone: AppMessageTone.error,
                          action: TextButton(
                            onPressed: () => _loadDetail(),
                            child: Text(uiText(context, zh: '重试', en: 'Retry')),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              AppStatusTag(label: _post.channelFor(locale)),
                              const SizedBox(width: AppSpacing.xs),
                              AppStatusTag(
                                label: _post.status.labelFor(locale),
                                outlined: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _post.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: <Widget>[
                              GestureDetector(
                                onTap:
                                    _post.canViewAuthorProfile &&
                                        _post.authorUserId.isNotEmpty
                                    ? _openAuthorProfile
                                    : null,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundImage:
                                      _post.isAnonymous ||
                                          _post.authorAvatarUrl.trim().isEmpty
                                      ? null
                                      : NetworkImage(
                                          AppConfig.resolveUrl(
                                            _post.authorAvatarUrl.trim(),
                                          ),
                                        ),
                                  child:
                                      _post.isAnonymous ||
                                          _post.authorAvatarUrl.trim().isEmpty
                                      ? Text(
                                          _post.isAnonymous
                                              ? uiText(
                                                  context,
                                                  zh: '匿',
                                                  en: 'A',
                                                )
                                              : _post
                                                    .authorAliasFor(locale)
                                                    .trim()
                                                    .characters
                                                    .first,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  '${_post.isAnonymous ? uiText(context, zh: '匿名身份', en: 'Anonymous') : _post.authorAliasFor(locale)} · ${_formatDateTime(_post.createdAt)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                uiText(
                                  context,
                                  zh: '${_post.viewCount} 阅读',
                                  en: '${_post.viewCount} views',
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                            ),
                            child: Divider(height: 1),
                          ),
                          PostContentBody(
                            content: _post.content,
                            contentFormat: _post.contentFormat,
                            markdownSource: _post.markdownSource,
                            selectable: !_post.isMarkdown,
                          ),
                          if (supplementaryImageUrls.isNotEmpty)
                            ImageGallery(images: supplementaryImageUrls),
                          if (_post.hasImage && supplementaryImageUrls.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                uiText(
                                  context,
                                  zh: '图片暂时不可用，请稍后重试',
                                  en: 'Images are temporarily unavailable. Please try again later.',
                                ),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.58),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              if (_post.canViewAuthorProfile &&
                                  _post.authorUserId.isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: _openAuthorProfile,
                                  icon: const Icon(Icons.person_outline),
                                  label: Text(
                                    uiText(
                                      context,
                                      zh: '查看主页',
                                      en: 'View profile',
                                    ),
                                  ),
                                ),
                              if (_post.canFollowAuthor &&
                                  _post.authorUserId.isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: _actionBusy
                                      ? null
                                      : _toggleFollowAuthor,
                                  icon: Icon(
                                    _post.isFollowingAuthor
                                        ? Icons.person_remove_alt_1_outlined
                                        : Icons.person_add_alt_1_outlined,
                                  ),
                                  label: Text(
                                    _post.isFollowingAuthor
                                        ? uiText(
                                            context,
                                            zh: '取消关注',
                                            en: 'Unfollow',
                                          )
                                        : uiText(
                                            context,
                                            zh: '关注作者',
                                            en: 'Follow author',
                                          ),
                                  ),
                                ),
                              OutlinedButton.icon(
                                onPressed: _actionBusy ? null : _like,
                                icon: const Icon(Icons.thumb_up_alt_outlined),
                                label: Text(
                                  uiText(
                                    context,
                                    zh: '点赞 ${_post.likeCount}',
                                    en: 'Like ${_post.likeCount}',
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _actionBusy ? null : _toggleFavorite,
                                icon: Icon(
                                  _post.isFavorited
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                ),
                                label: Text(
                                  '${_post.isFavorited ? uiText(context, zh: '取消收藏', en: 'Saved') : uiText(context, zh: '收藏', en: 'Save')} ${_post.favoriteCount}',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _actionBusy ? null : _report,
                                icon: const Icon(Icons.report_gmailerrorred),
                                label: Text(
                                  uiText(context, zh: '举报', en: 'Report'),
                                ),
                              ),
                              if (!_post.isMarkdown)
                                OutlinedButton.icon(
                                  onPressed: _copyPostContent,
                                  icon: const Icon(Icons.copy_all_rounded),
                                  label: Text(
                                    uiText(
                                      context,
                                      zh: '复制内容',
                                      en: 'Copy text',
                                    ),
                                  ),
                                ),
                              OutlinedButton.icon(
                                onPressed: _copyPostLink,
                                icon: const Icon(Icons.link_rounded),
                                label: Text(
                                  uiText(
                                    context,
                                    zh: '复制链接',
                                    en: 'Copy link',
                                  ),
                                ),
                              ),
                              if (_post.canMessageAuthor)
                                OutlinedButton.icon(
                                  onPressed: _actionBusy ? null : _requestDm,
                                  icon: const Icon(Icons.forum_outlined),
                                  label: Text(
                                    uiText(
                                      context,
                                      zh: '私信作者',
                                      en: 'Message author',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            uiText(
                              context,
                              zh: '评论区（${_countComments(_comments)}）',
                              en: 'Comments (${_countComments(_comments)})',
                            ),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          if (_comments.isEmpty)
                            AppStatePanel(
                              key: const Key('comments-empty-state'),
                              icon: Icons.chat_bubble_outline_rounded,
                              title: uiText(
                                context,
                                zh: '还没有评论',
                                en: 'No comments yet',
                              ),
                              message: uiText(
                                context,
                                zh: '欢迎留下第一条友善、具体的回复。',
                                en: 'Be the first to leave a kind, specific reply.',
                              ),
                              compact: true,
                            )
                          else
                            ..._comments.asMap().entries.map(
                              (MapEntry<int, CommentItem> entry) =>
                                  _CommentThreadTile(
                                    comment: entry.value,
                                    floorLabel: uiText(
                                      context,
                                      zh: '${entry.key + 1} 楼',
                                      en: '#${entry.key + 1}',
                                    ),
                                    onReply: _actionBusy
                                        ? null
                                        : (CommentItem comment) =>
                                              _prepareReply(comment: comment),
                                    onReport: _actionBusy
                                        ? null
                                        : (String commentId) =>
                                              _reportComment(commentId),
                                    onOpenAuthor: _openCommentAuthor,
                                  ),
                            ),
                          const SizedBox(height: 8),
                          if (_replyToCommentId != null &&
                              _replyToAlias != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      uiText(
                                        context,
                                        zh: '正在回复 $_replyToAlias',
                                        en: 'Replying to $_replyToAlias',
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _actionBusy
                                        ? null
                                        : () {
                                            setState(() {
                                              _replyToCommentId = null;
                                              _replyToAlias = null;
                                            });
                                          },
                                    icon: const Icon(Icons.close, size: 16),
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
                            minLines: 2,
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
                              FilledButton(
                                onPressed: _actionBusy ? null : _submitComment,
                                child: Text(
                                  _actionBusy
                                      ? uiText(
                                          context,
                                          zh: '提交中...',
                                          en: 'Submitting...',
                                        )
                                      : uiText(
                                          context,
                                          zh: '发送评论',
                                          en: 'Post comment',
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
    final Map<String, dynamic>? result = await _showReportDialog();
    if (result == null) return;

    await _runAction(
      action: () => AppRepositories.posts.report(
        targetType: 'post',
        targetId: _post.id,
        reason: result['reason'] as String,
        description: result['description'] as String?,
      ),
      success: uiTextGlobal(zh: '已提交举报', en: 'Report submitted'),
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
      success: uiTextGlobal(zh: '已举报评论', en: 'Comment reported'),
    );
  }

  Future<Map<String, dynamic>?> _showReportDialog() async {
    String? selectedReason;
    final TextEditingController descController = TextEditingController();

    // The value sent to the API stays Chinese; only the label is localized.
    const List<(String, String)> reasons = <(String, String)>[
      ('垃圾广告', 'Spam or advertising'),
      ('违法违规', 'Illegal content'),
      ('色情低俗', 'Sexual or vulgar content'),
      ('人身攻击', 'Personal attack'),
      ('虚假信息', 'Misinformation'),
      ('侵犯隐私', 'Privacy violation'),
      ('其他', 'Other'),
    ];

    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: Text(uiText(context, zh: '举报', en: 'Report')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        uiText(context, zh: '请选择举报原因：', en: 'Choose a reason:'),
                      ),
                      const SizedBox(height: 8),
                      ...reasons.map(
                        ((String, String) reason) => RadioListTile<String>(
                          title: Text(
                            uiText(context, zh: reason.$1, en: reason.$2),
                          ),
                          value: reason.$1,
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
                        decoration: InputDecoration(
                          labelText: uiText(
                            context,
                            zh: '补充说明（可选）',
                            en: 'Additional details (optional)',
                          ),
                          hintText: uiText(
                            context,
                            zh: '请详细描述举报原因',
                            en: 'Describe the issue in more detail',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(uiText(context, zh: '取消', en: 'Cancel')),
                  ),
                  FilledButton(
                    onPressed: selectedReason == null
                        ? null
                        : () => Navigator.of(context).pop(true),
                    child: Text(
                      uiText(context, zh: '确认举报', en: 'Submit report'),
                    ),
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
      _feedback(
        uiTextGlobal(
          zh: 'Markdown 帖子不支持复制内容',
          en: 'Copying is not supported for Markdown posts',
        ),
      );
      return;
    }
    final String body = _post.isMarkdown ? _post.markdownSource : _post.content;
    final String text = '[${_post.channel}] ${_post.title}\\n$body';
    await Clipboard.setData(ClipboardData(text: text));
    _feedback(uiTextGlobal(zh: '已复制帖子内容', en: 'Post content copied'));
  }

  Future<void> _copyPostLink() async {
    await Clipboard.setData(ClipboardData(text: postShareLink(_post.id)));
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
    final CommentItem comment = widget.comment;
    final String avatarUrl = AppConfig.resolveUrl(
      (comment.authorAvatar ?? '').trim(),
    );
    final Locale locale = Localizations.localeOf(context);
    final String authorAlias = comment.authorAliasFor(locale);
    final String fallback = authorAlias.trim().isEmpty
        ? uiTextFor(locale, zh: '匿', en: 'A')
        : authorAlias.trim().characters.first;
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurface.withValues(alpha: 0.58);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Stack(
        children: <Widget>[
          if (widget.depth > 0)
            Positioned(
              left: 5,
              top: 0,
              bottom: 0,
              child: Container(
                width: 1,
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
          if (widget.depth > 0)
            Positioned(
              left: 5,
              top: 28,
              child: Container(
                width: 12,
                height: 1,
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
          Column(
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
                      backgroundImage: avatarUrl.isEmpty
                          ? null
                          : NetworkImage(avatarUrl),
                      child: avatarUrl.isEmpty ? Text(fallback) : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: GestureDetector(
                                onTap: comment.authorUserId.isEmpty
                                    ? null
                                    : () => widget.onOpenAuthor(
                                        comment.authorUserId,
                                      ),
                                child: Text(
                                  authorAlias,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: comment.authorUserId.isEmpty
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: AppBreakpoints.isCompact(context)
                                  ? 104
                                  : 116,
                              child: Text(
                                _formatDateTime(comment.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            if (widget.floorLabel != null)
                              const SizedBox(width: 8),
                            if (widget.floorLabel != null)
                              SizedBox(
                                width: AppBreakpoints.isCompact(context)
                                    ? 36
                                    : 40,
                                child: Text(
                                  widget.floorLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                comment.content,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.84),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: widget.onReply == null
                        ? null
                        : () => widget.onReply!(comment),
                    icon: const Icon(Icons.reply_outlined, size: 16),
                    label: Text(uiText(context, zh: '回复', en: 'Reply')),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: _isLiked
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onPressed: _busy ? null : _toggleLike,
                    icon: Icon(
                      _isLiked
                          ? Icons.thumb_up_alt
                          : Icons.thumb_up_alt_outlined,
                      size: 16,
                    ),
                    label: Text('$_likeCount'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: widget.onReport == null
                        ? null
                        : () => widget.onReport!(comment.id),
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: Text(uiText(context, zh: '举报', en: 'Report')),
                  ),
                  if (comment.effectiveReplyCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 8),
                      child: Text(
                        uiText(
                          context,
                          zh: '${comment.effectiveReplyCount} 条回复',
                          en: comment.effectiveReplyCount == 1
                              ? '1 reply'
                              : '${comment.effectiveReplyCount} replies',
                        ),
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                ],
              ),
              if (comment.replies.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
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
            ],
          ),
        ],
      ),
    );
  }
}
