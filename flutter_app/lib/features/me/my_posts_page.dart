import 'package:flutter/material.dart';

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
  int _userLevel = 2;
  String _userLevelLabel = '二级用户';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的帖子')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.readingMaxWidth,
          ),
          child: _loading
              ? const AppStatePanel(
                  icon: Icons.article_outlined,
                  title: '正在加载我的帖子',
                  message: '正在同步发布记录和审核状态。',
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
                          title: '帖子加载失败',
                          message: _error!,
                          tone: AppMessageTone.error,
                          action: TextButton(
                            onPressed: _actionBusy ? null : _loadData,
                            child: const Text('重试'),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Text(
                        _userLevel == 1
                            ? '当前身份：$_userLevelLabel，可直接为自己的帖子设置置顶时长。'
                            : '当前身份：$_userLevelLabel，发帖后如需置顶，请提交管理员审核。',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.58),
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
                                  child: const Text('更新状态'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed:
                                      _actionBusy ||
                                          (_userLevel != 1 && post.isPinned)
                                      ? null
                                      : () => _handlePin(post),
                                  icon: const Icon(Icons.push_pin_outlined),
                                  label: Text(
                                    _userLevel == 1
                                        ? (post.isPinned ? '重新置顶' : '置顶帖子')
                                        : (post.isPinned ? '已置顶' : '申请置顶'),
                                  ),
                                ),
                                FilledButton.tonal(
                                  onPressed: _actionBusy
                                      ? null
                                      : () => _delete(post),
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_posts.isEmpty)
                      const AppStatePanel(
                        key: Key('my-posts-empty-state'),
                        icon: Icons.post_add_outlined,
                        title: '你还没有发布帖子',
                        message: '回到帖子流，使用发布按钮分享第一条内容。',
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
      final profile = await AppRepositories.users.fetchProfile();
      final List<PostItem> posts = await AppRepositories.posts.fetchMyPosts();
      if (!mounted) {
        return;
      }
      setState(() {
        _userLevel = profile.userLevel;
        _userLevelLabel = profile.userLevelLabel;
        _posts = posts;
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
      _toast('帖子状态已更新为 ${next.label}');
      await _loadData();
    } catch (error) {
      _toast('更新失败：$error');
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
          title: const Text('删除这条帖子？'),
          content: const Text('删除后无法恢复，相关内容将不再展示。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认删除'),
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
      _toast('帖子已删除');
      await _loadData();
    } catch (error) {
      _toast('删除失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _handlePin(PostItem post) async {
    final _PinActionInput? input = await _showPinDialog(
      direct: _userLevel == 1,
    );
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
      _toast(result.isDirect ? '帖子已置顶' : '置顶申请已提交');
    } catch (error) {
      _toast('操作失败：$error');
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
          builder:
              (BuildContext context, void Function(void Function()) setState) {
                return AlertDialog(
                  title: Text(direct ? '选择置顶时长' : '申请帖子置顶'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      DropdownButtonFormField<int>(
                        initialValue: selectedDuration,
                        decoration: const InputDecoration(labelText: '置顶时长'),
                        items: const <DropdownMenuItem<int>>[
                          DropdownMenuItem(value: 30, child: Text('30 分钟')),
                          DropdownMenuItem(value: 60, child: Text('1 小时')),
                          DropdownMenuItem(value: 120, child: Text('2 小时')),
                          DropdownMenuItem(value: 180, child: Text('3 小时')),
                          DropdownMenuItem(value: 1440, child: Text('1 天')),
                          DropdownMenuItem(value: 4320, child: Text('3 天')),
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
                          decoration: const InputDecoration(
                            labelText: '申请说明（可选）',
                            hintText: '例如：活动通知、紧急求助、时效性较强等',
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        _PinActionInput(
                          durationMinutes: selectedDuration,
                          reason: reasonController.text.trim(),
                        ),
                      ),
                      child: Text(direct ? '确认置顶' : '提交申请'),
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
