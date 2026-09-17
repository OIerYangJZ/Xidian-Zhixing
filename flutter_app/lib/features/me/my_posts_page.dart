import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/post_item.dart';
import '../../repositories/app_repositories.dart';
import '../../widgets/post_card.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  List<PostItem> _posts = const <PostItem>[];
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '我的帖子', en: 'My posts')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.readingMaxWidth,
          ),
          child: _loading
              ? AppStatePanel(
                  icon: Icons.article_outlined,
                  title: uiText(
                    context,
                    zh: '正在加载我的帖子',
                    en: 'Loading your posts',
                  ),
                  message: uiText(
                    context,
                    zh: '正在同步发布记录和审核状态。',
                    en: 'Syncing your publishing history and review status.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xs,
                    bottom: AppSpacing.xl,
                  ),
                  children: <Widget>[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: AppInlineMessage(
                          title: uiText(
                            context,
                            zh: '帖子加载失败',
                            en: 'Could not load your posts',
                          ),
                          message: _error!,
                          tone: AppMessageTone.error,
                          action: TextButton(
                            onPressed: _actionBusy ? null : _loadData,
                            child: Text(uiText(context, zh: '重试', en: 'Retry')),
                          ),
                        ),
                      ),
                    ..._posts.map(
                      (PostItem post) => Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.xs,
                              AppSpacing.md,
                              0,
                            ),
                            child: PostCard(
                              post: post,
                              onTap: () async {
                                final PostItem? updated =
                                    await openPostDetailPage(
                                      context,
                                      post: post,
                                    );
                                if (updated == null || !mounted) {
                                  return;
                                }
                                setState(() {
                                  _posts = _posts
                                      .map(
                                        (PostItem item) => item.id == updated.id
                                            ? updated
                                            : item,
                                      )
                                      .toList(growable: false);
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                OutlinedButton(
                                  onPressed: _actionBusy
                                      ? null
                                      : () => _updateStatus(post),
                                  child: Text(
                                    uiText(
                                      context,
                                      zh: '更新状态',
                                      en: 'Update status',
                                    ),
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: _actionBusy
                                      ? null
                                      : () => _handlePin(post),
                                  icon: const Icon(Icons.push_pin_outlined),
                                  label: Text(
                                    post.isPinned
                                        ? uiText(
                                            context,
                                            zh: '重新置顶',
                                            en: 'Re-pin',
                                          )
                                        : uiText(
                                            context,
                                            zh: '置顶帖子',
                                            en: 'Pin post',
                                          ),
                                  ),
                                ),
                                FilledButton.tonal(
                                  onPressed: _actionBusy
                                      ? null
                                      : () => _delete(post),
                                  child: Text(
                                    uiText(context, zh: '删除', en: 'Delete'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_posts.isEmpty)
                      AppStatePanel(
                        key: const Key('my-posts-empty-state'),
                        icon: Icons.post_add_outlined,
                        title: uiText(
                          context,
                          zh: '你还没有发布帖子',
                          en: 'You have not published any posts yet',
                        ),
                        message: uiText(
                          context,
                          zh: '回到帖子流，使用发布按钮分享第一条内容。',
                          en: 'Go back to the feed and use the compose button to share your first post.',
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<PostItem> posts = await AppRepositories.posts.fetchMyPosts();
      if (!mounted) {
        return;
      }
      setState(() {
        _posts = posts;
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

  Future<void> _updateStatus(PostItem post) async {
    final PostStatus next = switch (post.status) {
      PostStatus.ongoing => PostStatus.resolved,
      PostStatus.resolved => PostStatus.closed,
      PostStatus.closed => PostStatus.ongoing,
    };

    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.posts.updateMyPostStatus(
        postId: post.id,
        status: next,
      );
      if (!mounted) {
        return;
      }
      _toast(
        uiTextGlobal(
          zh: '帖子状态已更新为 ${next.labelFor(const Locale('zh', 'CN'))}',
          en: 'Post status updated to ${next.labelFor(const Locale('en'))}',
        ),
      );
      await _loadData();
    } catch (error) {
      _toast(uiTextGlobal(zh: '更新失败：$error', en: 'Update failed: $error'));
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _delete(PostItem post) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(uiText(context, zh: '删除这条帖子？', en: 'Delete this post?')),
          content: Text(
            uiText(
              context,
              zh: '删除后无法恢复，相关内容将不再展示。',
              en: 'This cannot be undone. The post will no longer be visible.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(uiText(context, zh: '取消', en: 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(uiText(context, zh: '确认删除', en: 'Delete')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.posts.deleteMyPost(post.id);
      if (!mounted) {
        return;
      }
      _toast(uiTextGlobal(zh: '帖子已删除', en: 'Post deleted'));
      await _loadData();
    } catch (error) {
      _toast(uiTextGlobal(zh: '删除失败：$error', en: 'Delete failed: $error'));
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _handlePin(PostItem post) async {
    final _PinActionInput? input = await _showPinDialog(direct: false);
    if (input == null) {
      return;
    }
    setState(() {
      _actionBusy = true;
    });
    try {
      final result = await AppRepositories.posts.submitPinRequest(
        postId: post.id,
        durationMinutes: input.durationMinutes,
        reason: input.reason,
      );
      if (!mounted) {
        return;
      }
      if (result.post != null) {
        setState(() {
          _posts = _posts
              .map((PostItem item) => item.id == post.id ? result.post! : item)
              .toList(growable: false);
        });
      }
      _toast(
        result.isDirect
            ? uiTextGlobal(zh: '帖子已置顶', en: 'Post pinned')
            : uiTextGlobal(zh: '置顶申请已提交', en: 'Pin request submitted'),
      );
    } catch (error) {
      _toast(uiTextGlobal(zh: '操作失败：$error', en: 'Action failed: $error'));
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<_PinActionInput?> _showPinDialog({required bool direct}) {
    final TextEditingController reasonController = TextEditingController();
    int selectedDuration = 30;
    return showDialog<_PinActionInput>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            return AlertDialog(
              title: Text(
                direct
                    ? uiText(context, zh: '选择置顶时长', en: 'Choose a pin duration')
                    : uiText(
                        context,
                        zh: '申请帖子置顶',
                        en: 'Request a pinned post',
                      ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    initialValue: selectedDuration,
                    decoration: InputDecoration(
                      labelText: uiText(
                        context,
                        zh: '置顶时长',
                        en: 'Pin duration',
                      ),
                    ),
                    items: <DropdownMenuItem<int>>[
                      DropdownMenuItem(
                        value: 30,
                        child: Text(
                          uiText(context, zh: '30 分钟', en: '30 minutes'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 60,
                        child: Text(uiText(context, zh: '1 小时', en: '1 hour')),
                      ),
                      DropdownMenuItem(
                        value: 120,
                        child: Text(uiText(context, zh: '2 小时', en: '2 hours')),
                      ),
                      DropdownMenuItem(
                        value: 180,
                        child: Text(uiText(context, zh: '3 小时', en: '3 hours')),
                      ),
                      DropdownMenuItem(
                        value: 1440,
                        child: Text(uiText(context, zh: '1 天', en: '1 day')),
                      ),
                      DropdownMenuItem(
                        value: 4320,
                        child: Text(uiText(context, zh: '3 天', en: '3 days')),
                      ),
                    ],
                    onChanged: (int? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        selectedDuration = value;
                      });
                    },
                  ),
                  if (!direct) ...<Widget>[
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: uiText(
                          context,
                          zh: '申请说明（可选）',
                          en: 'Reason (optional)',
                        ),
                        hintText: uiText(
                          context,
                          zh: '例如：活动通知、紧急求助、时效性较强等',
                          en: 'e.g. event announcement, urgent request, time-sensitive',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(uiText(context, zh: '取消', en: 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _PinActionInput(
                      durationMinutes: selectedDuration,
                      reason: reasonController.text.trim(),
                    ),
                  ),
                  child: Text(
                    direct
                        ? uiText(context, zh: '确认置顶', en: 'Pin post')
                        : uiText(context, zh: '提交申请', en: 'Submit request'),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(reasonController.dispose);
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PinActionInput {
  const _PinActionInput({required this.durationMinutes, required this.reason});

  final int durationMinutes;
  final String reason;
}
