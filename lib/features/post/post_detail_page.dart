import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/comment_item.dart';
import '../../models/post_item.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/emoji/emoji_assistant_bar.dart';

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
    _loadDetail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帖子详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: <Widget>[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_post.channel),
                          ),
                          const SizedBox(width: 8),
                          Chip(label: Text(_post.status.label)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _post.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(_post.content),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children: _post.tags
                            .map((String tag) => Chip(label: Text('#$tag')))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Text('匿名身份：${_post.authorAlias}'),
                      Text('发布时间：${_post.createdAt.toLocal()}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: _actionBusy ? null : _like,
                            icon: const Icon(Icons.thumb_up_alt_outlined),
                            label: Text('点赞 ${_post.likeCount}'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _actionBusy ? null : _toggleFavorite,
                            icon: Icon(_post.isFavorited
                                ? Icons.bookmark
                                : Icons.bookmark_border),
                            label: Text(
                              '${_post.isFavorited ? '取消收藏' : '收藏'} ${_post.favoriteCount}',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _actionBusy ? null : _report,
                            icon: const Icon(Icons.report_gmailerrorred),
                            label: const Text('举报'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _copyPostContent,
                            icon: const Icon(Icons.copy_all_rounded),
                            label: const Text('复制内容'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '评论区（${_comments.length}）',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      if (_comments.isEmpty)
                        const Text('暂无评论，来抢沙发。')
                      else
                        ..._comments.asMap().entries.map(
                              (MapEntry<int, CommentItem> entry) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                    child: Text('${entry.key + 1}')),
                                title: Text(entry.value.authorAlias),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(entry.value.content),
                                    Row(
                                      children: <Widget>[
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          onPressed: _actionBusy
                                              ? null
                                              : () => _prepareReply(
                                                    comment: entry.value,
                                                  ),
                                          icon: const Icon(
                                            Icons.reply_outlined,
                                            size: 16,
                                          ),
                                          label: const Text('回复'),
                                        ),
                                        Text(
                                          '${entry.value.likeCount} 赞',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  onPressed: _actionBusy
                                      ? null
                                      : () => _reportComment(entry.value.id),
                                  icon: const Icon(Icons.flag_outlined),
                                ),
                              ),
                            ),
                      const SizedBox(height: 8),
                      if (_replyToCommentId != null && _replyToAlias != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(
                                  alpha: 0.08,
                                ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  '正在回复 $_replyToAlias',
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
                                tooltip: '取消回复',
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
                              ? '发表评论（支持一级评论/二级回复）'
                              : '输入回复内容',
                        ),
                      ),
                      const SizedBox(height: 4),
                      EmojiAssistantBar(controller: _commentController),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _actionBusy ? null : _submitComment,
                          child: Text(_actionBusy ? '提交中...' : '发送评论'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final PostItem detail =
          await AppRepositories.posts.fetchPostDetail(widget.post.id);
      final List<CommentItem> comments =
          await AppRepositories.posts.fetchComments(widget.post.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _post = detail;
        _comments = comments;
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
      final List<CommentItem> comments =
          await AppRepositories.posts.fetchComments(_post.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = comments;
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

      final int nextCount = result.favoriteCount ??
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
    await _runAction(
      action: () => AppRepositories.posts.report(
        targetType: 'post',
        targetId: _post.id,
        reason: '其他',
      ),
      success: '已提交举报',
    );
  }

  Future<void> _reportComment(String commentId) async {
    await _runAction(
      action: () => AppRepositories.posts.report(
        targetType: 'comment',
        targetId: commentId,
        reason: '其他',
      ),
      success: '已举报评论',
    );
  }

  Future<void> _copyPostContent() async {
    final String text = '[${_post.channel}] ${_post.title}\\n${_post.content}';
    await Clipboard.setData(ClipboardData(text: text));
    _feedback('已复制帖子内容');
  }

  void _prepareReply({
    required CommentItem comment,
  }) {
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
