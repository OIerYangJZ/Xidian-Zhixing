import 'package:flutter/material.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../design_system/design_system.dart';
import '../../models/my_comment_item.dart';
import '../../models/post_item.dart';
import '../../repositories/app_repositories.dart';
import '../../core/l10n/ui_text.dart';

class MyCommentsPage extends StatefulWidget {
  const MyCommentsPage({super.key});

  @override
  State<MyCommentsPage> createState() => _MyCommentsPageState();
}

class _MyCommentsPageState extends State<MyCommentsPage> {
  List<MyCommentItem> _items = const <MyCommentItem>[];
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '我的评论', en: 'My comments')),
      ),
      body: ZxPaper(
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: <Widget>[
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ZxInlineMessage(
                                  message: _error!,
                                  tone: ZxMessageTone.danger,
                                  actionLabel: uiText(
                                    context,
                                    zh: '重试',
                                    en: 'Retry',
                                  ),
                                  onAction: _load,
                                ),
                              ),
                            if (_items.isEmpty && _error == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 60),
                                child: ZxStatePanel(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  title: uiText(
                                    context,
                                    zh: '你还没有发表评论',
                                    en: 'You have not commented yet',
                                  ),
                                ),
                              ),
                            for (final MyCommentItem row in _items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ZxCard(
                                  key: Key('my-comment-${row.id}'),
                                  onTap: row.postId.trim().isEmpty
                                      ? null
                                      : () => _openPost(row),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      Text(
                                        row.content,
                                        style: ZxType.body.copyWith(
                                          color: t.text,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: t.bgSunk,
                                          borderRadius: ZxRadius.badgeAll,
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            Icon(
                                              Icons.article_outlined,
                                              size: 15,
                                              color: t.text3,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                row.postTitle.trim().isEmpty
                                                    ? uiText(
                                                        context,
                                                        zh: '原帖',
                                                        en: 'Original post',
                                                      )
                                                    : row.postTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: ZxType.caption.copyWith(
                                                  fontSize: 13,
                                                  color: t.text2,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: <Widget>[
                                          Text(
                                            row.timeText,
                                            style: ZxType.caption.copyWith(
                                              color: t.text3,
                                            ),
                                          ),
                                          const Spacer(),
                                          ZxButton(
                                            key: Key(
                                              'my-comment-delete-${row.id}',
                                            ),
                                            label: uiText(
                                              context,
                                              zh: '删除',
                                              en: 'Delete',
                                            ),
                                            icon: Icons.delete_outline_rounded,
                                            variant: ZxButtonVariant.ghost,
                                            small: true,
                                            onPressed: _actionBusy
                                                ? null
                                                : () => _delete(row.id),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _openPost(MyCommentItem row) async {
    try {
      final PostItem post = await AppRepositories.posts.fetchPostDetail(
        row.postId,
      );
      if (!mounted) return;
      await openPostDetailPage(context, post: post);
    } catch (_) {
      if (!mounted) return;
      zxShowToast(
        context,
        uiText(
          context,
          zh: '原帖已删除或不可见',
          en: 'The original post was deleted or is not visible',
        ),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<MyCommentItem> items = await AppRepositories.users
          .fetchMyComments();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
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

  Future<void> _delete(String commentId) async {
    final bool confirmed = await zxConfirm(
      context,
      title: uiText(context, zh: '删除这条评论？', en: 'Delete this comment?'),
      message: uiText(context, zh: '删除后无法恢复。', en: 'This cannot be undone.'),
      confirmLabel: uiText(context, zh: '删除', en: 'Delete'),
      cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.users.deleteMyComment(commentId);
      if (!mounted) {
        return;
      }
      zxShowToast(context, uiText(context, zh: '评论已删除', en: 'Comment deleted'));
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      zxShowToast(
        context,
        uiText(context, zh: '删除失败：$error', en: 'Delete failed: $error'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }
}
